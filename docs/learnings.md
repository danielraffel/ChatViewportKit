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

## Performance Notes

(Add profiling results and optimization learnings here)

## Apple Documentation References

(Add links to relevant Apple docs discovered via sosumi MCP here)
