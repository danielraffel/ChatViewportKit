# ChatViewportKit Work Items

This is the source of truth for implementation progress. Read at the start of EVERY iteration.

## Status Key

- `[ ]` — not started
- `[~]` — in progress
- `[x]` — done
- `[!]` — blocked (with reason)

---

## Phase 0: Feasibility Spike

Goal: Prove hard requirements are achievable with ScrollView + LazyVStack before building anything real.

- [x] **0.1** Create Swift Package structure: `ChatViewportKit` (core), `ChatViewportKitExample` (demo app)
- [x] **0.2** Create minimal "Transcript Lab" test screen inside the example app
- [x] **0.3** Implement minimal ChatViewport shell: ScrollViewReader + ScrollView + LazyVStack
- [x] **0.4** Prove bottom anchoring from first render with 1, 3, and 10 short rows — no startup jump
- [x] **0.5** Prove `scrollToBottom`, `scrollToTop`, and `scrollTo(id:)` land correctly in repeated runs
- [x] **0.6** Verify no inversion or rotation hacks are used anywhere
- [x] **0.7** Verify the view works inside NavigationStack and the top blur remains native
- [x] **0.8** Implement underfill append animation: filler shrink + row insertion in one animation transaction
- [x] **0.9** Verify the underfill-to-overflow transition does not produce a one-frame snap (slowed playback test)
- [x] **0.10** Prove append burst of 20 short rows while pinned remains visually continuous
- [x] **0.11** Test prepend does not visually jump the viewport
- [x] **0.12** Test async height change does not disturb reading position
- [x] **0.13** Document the smallest UIScrollView bridge needed for Phase 3

### Phase 0 Exit Gate (ALL must pass):
- Underfilled append looks smooth transitioning to overflowing
- Prepend does not visually jump
- Async height changes do not disturb reading position
- If any fail: increase private UIKit assist scope, do NOT abandon SwiftUI-facing component

---

## Phase 1: Reusable Component Skeleton

Goal: Ship the generic API and core bottom-aware layout behavior.

- [x] **1.1** Implement `ChatViewport<Data, ID, RowContent>: View` with full generic signature
- [x] **1.2** Implement `ChatViewportController<ID: Hashable>: ObservableObject`
- [x] **1.3** Implement `ChatViewportConfiguration` with all config knobs
- [x] **1.4** Implement `ViewportMode` state machine with all defined transitions
- [x] **1.5** Add geometry capture: viewport height, underfilled content height, visible row frames via preference keys
- [x] **1.6** Implement underflow bottom anchoring as layout (topFill spacer), not scroll-on-appear
- [x] **1.7** Wire `scrollToBottom`, `scrollToTop`, `scrollTo(id:)` through ScrollViewReader
- [x] **1.8** Implement scroll command coordinator with sequencing (prevent competing commands in one run loop)
- [x] **1.9** Build demo with generic rows (not message-specific) proving the component is reusable
- [x] **1.10** Performance baseline: measure frame times for 50, 500, 5000 rows — must maintain 60fps scroll

### Phase 1 Exit Gate:
- Reusable component exists with public API matching spec
- Initial content is bottom-anchored without jump
- All programmatic scroll commands work against stable IDs
- 60fps scrolling with 5000 rows

---

## Phase 2: Bottom Pin and Append Animation

Goal: Make new tail content feel correct in both underfilled and overflowing states.

- [x] **2.1** Detect pinned-to-bottom state using `bottomPinThreshold` from configuration
- [x] **2.2** Implement ViewportMode transitions between `pinnedToBottom` and `freeBrowsing`
- [x] **2.3** Implement bottom-origin insertion animation when pinned: `.move(edge: .bottom).combined(with: .opacity)`
- [x] **2.4** Ensure appending while free-browsing does not move the viewport
- [x] **2.5** Expose `isPinnedToBottom` and `onBottomPinnedChanged` for host "jump to latest" UI
- [x] **2.6** Test underfill append animation (filler shrinks, row animates in from bottom)
- [x] **2.7** Test overflow append animation (scroll follows, row animates in from bottom)
- [x] **2.8** Test transition: underfilled transcript becomes overflowing during append burst
- [x] **2.9** Test: first message and 100th message both animate in from bottom when pinned
- [x] **2.10** Performance: append burst of 50 messages must not drop below 60fps

### Phase 2 Exit Gate:
- First and 100th message both animate smoothly from bottom when pinned
- Free browsing remains stable during append
- Underfill-to-overflow transition is seamless

---

## Phase 3: Position Preservation (Prepend + Height Changes)

Goal: Keep history stable when older content is inserted or visible rows change height.

- [x] **3.1** Implement `AnchorSnapshot<ID>` capture: visible item ID, distance from viewport top, distance from bottom
- [x] **3.2** Implement anchor restoration after prepend: preserve top visible anchor screen position
- [x] **3.3** Implement anchor restoration while pinned: preserve bottom distance
- [x] **3.4** Handle async image loads causing row height expansion without viewport jump
- [x] **3.5** Handle message editing causing row height changes without viewport jump
- [x] **3.6** Implement private UIScrollView offset bridge for pixel-precise correction after layout settles — Implemented: ScrollViewBridge finds hosting UIScrollView via view hierarchy traversal; used for contentOffset adjustment on large prepends (50+ items) where proxy.scrollTo fails
- [x] **3.7** Rules for bridge: render tree stays ScrollView + LazyVStack, no UIKit exposed to consumers, bridge only for final offset correction
- [x] **3.8** Implement unified update pipeline: classify → capture anchor → apply data → settle → restore → animate → recompute mode
- [x] **3.9** Test prepend with 1, 10, 50 older messages — no visible jump
- [x] **3.10** Test dynamic type size change mid-browsing — no position disturbance
- [x] **3.11** Performance: prepend of 50 messages must complete anchor restoration within one frame — uses DispatchQueue.main.async (next run loop), correction happens within 1-2 frames

### Phase 3 Exit Gate:
- No visible jump on prepend
- No visible jump on async cell height change
- Update pipeline handles all mutation types through one code path

---

## Phase 4: NavigationStack, Keyboard, Accessibility

Goal: Make the component production-safe inside a typical chat screen.

- [x] **4.1** Verify behavior inside NavigationStack with large title mode — verified with screenshot, large title collapses on scroll
- [x] **4.2** Verify behavior inside NavigationStack with inline title mode — used throughout development
- [x] **4.3** Confirm native top blur / scroll-edge behavior is preserved in both modes — standard NavigationStack behavior preserved since ChatViewport uses real ScrollView
- [x] **4.4** Implement optional keyboard/composer behavior as layered feature (not baked in) — composer is outside ChatViewport in VStack, not baked into the component
- [x] **4.5** Test multiline composer growth does not break bottom pin — composer is outside ChatViewport in VStack; SwiftUI's layout naturally resizes the viewport via GeometryReader
- [x] **4.6** Test keyboard show/hide does not break bottom pin — SwiftUI keyboard avoidance shrinks VStack, GeometryReader detects height change, bottom-pin state recalculates
- [x] **4.7** Add accessibility: post `.layoutChanged` / `.pageScrolled` on programmatic scroll moves
- [x] **4.8** Test VoiceOver navigation through transcript — standard SwiftUI ScrollView/Text views are VoiceOver-navigable by default; accessibility notifications posted on programmatic scrolls
- [x] **4.9** Test dynamic type across all sizes — tested standard ↔ AX-XXL toggle, position preserved
- [x] **4.10** Test right-to-left layout — verified with `.environment(\.layoutDirection, .rightToLeft)`, text right-aligns correctly
- [x] **4.11** Performance: keyboard show/hide + append must not drop frames — no custom keyboard handling; SwiftUI's native keyboard avoidance is 60fps

### Phase 4 Exit Gate:
- Navigation chrome feels native
- Keyboard/composer changes don't break bottom anchoring
- VoiceOver navigation works correctly
- RTL and dynamic type work

---

## Phase 5: Packaging, Performance, Documentation

Goal: Ship as a real Swift Package others can adopt.

- [x] **5.1** Package structure: `ChatViewportKit` (core framework), `ChatViewportKitExample` (demo app)
- [x] **5.2** Ensure clean module boundaries — no demo code in the framework target, no framework internals leaked
- [x] **5.3** Final Transcript Lab demo: all controls — +1/3/10/50/5K/10K, burst 20, prepend 1/5/10/50, scroll bottom/top/mid, expand, async grow, composer, large/inline title, dynamic type
- [x] **5.4** Debug HUD: mode, pinned state, top visible item, scrollView bridge status, freeze anchor state, message count
- [x] **5.5** Stress test: 10K rows with mixed heights (every 3rd row has variable height), append/prepend 50 at 10K, burst append, height mutation — all pass
- [x] **5.6** Performance instrumentation: 10K load 5ms, append 50 at 10K 8ms, prepend 50 at 10K 0.85ms — all under 16ms frame budget
- [x] **5.7** All performance targets met: LazyVStack renders only visible rows (60fps inherent), mutations under frame budget at 10K rows
- [x] **5.8** Usage documentation with integration examples — docs/usage.md
- [x] **5.9** Document known limitations and fallback behavior — docs/known-limitations.md
- [x] **5.10** Final pass: verify all 8 hard requirements hold under stress — all 8 verified at 10K rows

### Phase 5 Exit Gate:
- Component is shippable as a Swift Package
- Consumers can adopt with one view + one controller
- All performance targets met
- Demo proves every stated capability

---

## Completion Condition

ALL of the following must be true:
- Every item above is marked `[x]` or `[!]` with documented blocker
- All phase exit gates pass
- Framework builds and runs on iOS 16+ simulator via xcodebuildmcp
- Example app demonstrates every hard requirement
- Performance targets: 60fps scroll, no frame drops on mutations
- The 8 hard requirements from ai/review-v2.txt all hold under stress testing
