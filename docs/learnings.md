# ChatViewportKit Development Learnings

Track non-obvious discoveries, gotchas, and solutions found during implementation.
Check this file before starting any work item.

---

## Architecture Decisions

- v1 approach (UICollectionView engine) was rejected — LazyVStack is a hard requirement
- v2 approach (ScrollView + LazyVStack) is the accepted plan
- Private UIScrollView bridge is planned for Phase 3 ONLY for pixel-precise offset correction
- The bridge must NOT replace the SwiftUI render tree or expose UIKit to consumers

## Known SwiftUI Scroll Challenges

### LazyVStack + topFill spacer chicken-and-egg problem
- A separate `Color.clear.frame(height: topFill)` spacer ABOVE a LazyVStack does NOT work
- When topFill = viewportHeight (content not yet measured), the spacer pushes the LazyVStack entirely below the viewport
- Since LazyVStack is lazy, it won't render any rows that are off-screen, so content height stays 0 forever
- **Solution**: Use `.frame(minHeight: viewportHeight, alignment: .bottom)` on the LazyVStack itself
- This makes the LazyVStack occupy the full viewport height but aligns its content to the bottom
- When content < viewport, alignment pushes rows to bottom; when content > viewport, the frame grows naturally
- This avoids the chicken-and-egg problem because the rows are always within the visible frame

### ForEach with wrapper structs breaks ScrollViewReader.scrollTo
- Using `ForEach(dataElements, id: \.id)` where `dataElements` is a computed property returning wrapper structs BREAKS `ScrollViewReader.scrollTo`
- The proxy.scrollTo call executes but has no visible effect — the scroll doesn't happen
- **Solution**: Use `ForEach(items.indices, id: \.self)` with direct `.id(itemID)` on the content view
- This keeps the `.id()` modifier on the actual row view, which ScrollViewReader can find
- Raw SwiftUI `ForEach(messages) { msg in ... .id(msg.id) }` also works — the issue is specifically with intermediate wrapper types in the ForEach data source
- `ForEach(Array(data), id: idKeyPath)` works for both scrollTo and animations — this is the correct pattern for generic data

### ForEach with integer indices breaks animations on prepend
- `ForEach(items.indices, id: \.self)` uses integer indices as stable identity
- When items are prepended, indices shift: what was at index 0 is now at index N
- SwiftUI treats this as "old item 0 changed content" rather than "new items were inserted"
- This causes incorrect animations and diffing behavior
- **Solution**: Always use the actual item ID (UUID, etc.) as the ForEach identity, not the array index

## Phase 0 Gate Test Results

All three Phase 0 gate tests pass with basic SwiftUI ScrollView + LazyVStack:

1. **Underfill-to-overflow transition**: Smooth. `.frame(minHeight:, alignment: .bottom)` handles underfill, auto-scroll-to-bottom on append handles overflow. No one-frame snap observed.
2. **Prepend does not jump**: Passes naturally. SwiftUI preserves scroll position when items are inserted at array index 0, because ForEach uses stable item IDs (UUIDs), not indices. The viewport stays on the same visible items.
3. **Async height change**: Passes naturally. Both above-viewport and in-viewport height changes do not disturb the reading position. SwiftUI's layout system handles height changes gracefully.

### Key insight
SwiftUI's ScrollView + LazyVStack with proper item IDs handles all three gate tests WITHOUT any UIScrollView bridge. The bridge (Phase 3) may still be needed for:
- Pixel-precise anchor restoration when content offset needs sub-point correction
- Edge cases where SwiftUI's automatic position preservation isn't sufficient under rapid mutations
- Reading exact scroll offset for bottom-pin detection (preference key approach may suffice)

## UIScrollView Bridge Assessment (for Phase 3)

### What the bridge needs to do
- Read the current contentOffset for bottom-pin detection
- Set contentOffset for pixel-precise anchor restoration after data mutations
- Observe scroll events (didScroll, didEndDecelerating) for mode transitions

### Smallest viable bridge
- `UIViewRepresentable` that uses `introspect`-style approach to find the hosting UIScrollView
- OR a transparent `UIViewRepresentable` overlay that captures the UIScrollView reference from the view hierarchy
- Store the UIScrollView reference weakly in the controller
- Read/write contentOffset only; never modify contentSize, delegate, or subview hierarchy
- The SwiftUI ScrollView + LazyVStack remains the ONLY render tree; bridge is observation + correction only

### What the bridge must NOT do
- Replace or wrap the SwiftUI ScrollView
- Install a custom UIScrollViewDelegate (would break SwiftUI's internal delegate)
- Modify contentInset, contentSize, or any layout properties
- Be exposed in the public API

### Bulk insert + scrollTo race condition
- When 5000+ items are added synchronously, `proxy.scrollTo(lastID, anchor: .bottom)` may fail silently
- LazyVStack hasn't materialized the target row yet, so ScrollViewReader can't find it
- **Workaround**: For initial bulk loads, delay the scroll with `DispatchQueue.main.asyncAfter`
- This doesn't affect incremental appends (1-50 at a time) because the target row is near the current viewport

## Performance Notes

### Phase 1 Baseline
- 5001 messages loaded in ~112ms (array allocation + SwiftUI state update)
- LazyVStack renders only ~11 visible rows regardless of total count
- Scrolling with LazyVStack is inherently 60fps since only visible rows are rendered/laid out
- Bulk insert of 5000 items: no visible hang (112ms is under one animation frame budget at 60fps)

## UIScrollView Bridge Implementation

### ScrollViewBridge placement matters
- The `ScrollViewBridge` (UIViewRepresentable) must be placed INSIDE the ScrollView content (e.g., as `.background()` on the LazyVStack), NOT on the ScrollView itself
- Placing it as `.background()` on the ScrollView makes the bridge view a sibling of the UIScrollView, not a descendant
- The bridge traverses the view hierarchy upward (`superview` chain) to find the UIScrollView, so it must be a descendant
- Symptom of wrong placement: `scrollViewRef` stays nil

### Prepend detection via freezeAnchor flag
- Do NOT detect prepend by comparing first/last IDs in `onChange(of: data.count)`
- SwiftUI's `onChange` closure may capture stale `data` references from a previous render cycle
- This causes `currentLastID == previousLastID` comparisons to be unreliable
- **Solution**: Use the `controller.freezeAnchor` flag (set by `prepareToPrepend()`) as the definitive prepend signal
- This is more reliable because it's set by the host before the data mutation, not derived from stale view state

### Prepend offset correction timing
- `setContentOffset` called synchronously in `onChange(of: data.count)` gets overridden by SwiftUI's next layout pass
- **Solution**: Capture `contentOffset.y` and `contentSize.height` before the layout pass, then adjust after a short delay (`DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)`)
- After layout, `contentSize.height` reflects the new items; `delta = newSize - capturedSize` gives the exact offset adjustment needed
- Formula: `newOffset.y = capturedOffsetY + delta`
- Tested and verified for prepend counts of 1, 10, and 50 items — all preserve scroll position

## Apple Documentation References

(Add links to relevant Apple docs discovered via sosumi MCP here)
