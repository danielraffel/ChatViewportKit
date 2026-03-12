# scrollTo(id:) Development Learnings

## From Research Phase

### LazyVStack materialization behavior
- LazyVStack correctly materializes rows around wherever you set contentOffset
- You don't need the target view to exist — you need to know WHERE it should be
- setContentOffset triggers materialization of the right neighborhood

### Preference key performance
- DO NOT accumulate all row frames in a PreferenceKey reduce — O(n) per frame
- Record heights via direct controller method calls in existing GeometryReader
- Current RowFramesPreference correctly folds to single topmost row (O(1) reduce)
- Do NOT add TargetRowFramePreference — preference timing is unreliable across iOS versions
- onPreferenceChange fires asynchronously relative to UIKit layout — can't depend on it in tight probe loop

### Timing
- SwiftUI's withAnimation overrides setContentOffset — need delays
- layoutIfNeeded() forces synchronous UIKit layout before reading contentSize
- Budget TWO async hops per probe: one for layoutIfNeeded, one for SwiftUI state settle
- iOS 16 needs 50ms between hops; iOS 17+ can use bare DispatchQueue.main.async
- Probe delay of 0.05-0.08s baseline; 0.1s for iOS 16

### @Published pitfall
- Session state (idScrollTargetID, idScrollInFlight) must NOT be @Published
- Changing @Published re-evaluates all materialized row bodies — creates feedback loop during probing
- Use plain stored properties + existing commandGeneration counter for view triggering

### Mode transition guard
- updateBottomPinState must check `idScrollInFlight` and early-return during probing
- .programmaticScroll mode alone is NOT sufficient — current guard logic doesn't cover it
- setContentOffset during probe fires ScrollOffsetPreference which calls updateBottomPinState

### Visual smoothness
- Users WILL see wrong content flash if estimate is off by >50px without mitigation
- UICollectionView has the same estimate→correct problem — it's not unique to SwiftUI
- Snapshot overlay (snapshotView(afterScreenUpdates: false)) is the correct masking strategy
- Opacity 0 breaks visual continuity and is bad for accessibility
- Animate only tiny residual corrections (<100pt); snap everything else
- Skip animation for Reduce Motion users
- Skip overlay entirely for nearby targets (within ~30 rows)

### Lazy reindexing
- Don't rebuild [ID: Int] index on every data mutation
- Streaming chat appends would cause thousands of unnecessary reindexes
- Build lazily only when scrollTo(id:) is called

### Community prior art
- simplex-chat: EndlessScrollView with averageItemHeight — works but replaces LazyVStack entirely
  - Runs entire probe loop synchronously within one runloop tick (up to 200 iterations)
  - User sees only final position — no flashing
  - This only works because they own the scroll engine (raw UIScrollView + manual cells)
- anytype-swift: UICollectionView + UIHostingConfiguration — works but full rewrite
- No known successful LazyVStack + height-index implementation in the wild
- We may be the first to ship this pattern if it works

### SwiftUI Pro review findings
- `Array(data)` in ForEach creates O(n) copy on every body evaluation — fix for 10K performance
- GCD is correct for probe-align (UIKit layoutIfNeeded flush), not Swift concurrency Task — document inline
- After layoutIfNeeded(), SwiftUI preference data may NOT be updated yet — read UIKit subview frames directly during probing
- All new onChange closures must follow body-prepass pattern (read controller state, not captured data) to avoid staleness
- ObservableObject is correct for iOS 16+ (Observable requires iOS 17+)
- Don't create a view-level protocol — would force AnyView type erasure, performance anti-pattern

### Known risks
- Cold-cache jumps (no measured heights) rely on content-proportional estimate
- Width changes invalidate all cached heights — call invalidateAll()
- Session cancellation must be airtight — leaked sessions cause mode corruption
- Every exit path in the probe loop MUST clear session state
- Snapshot overlay must live on scroll view's SUPERVIEW — if added as child of scroll view, it moves with content offset
- Cancel sessions on count change, height mutations, AND Dynamic Type changes (not just count)
- HeightIndex alone doesn't tell you where the target actually landed for .center anchors — need supplementary visible-frame query from bridge after layoutIfNeeded
- Stale height cache after in-place height mutations (expand/collapse) or Dynamic Type changes — invalidate affected entries
- Unstable or duplicate IDs will break the lazy [ID: Int] index — document as precondition

## From Phase A4 Testing

### Proportional estimation beats averageHeight for cold cache
- When few heights are measured (<100), `contentSize * (targetIndex / totalItems)` is far more reliable than HeightIndex `averageHeight * index`
- With only 18 measured heights from the bottom of the list, avgH was 61.6pt (biased by tall items), causing overshoot to 348K when target was at ~257K
- Proportional estimate uses UIKit's known contentSize which already accounts for all estimated heights
- Threshold: use HeightIndex when >100 heights measured, proportional otherwise

### Stale height invalidation on data replacement
- When both first AND last IDs change simultaneously, it signals a full data replacement
- Old UUID-keyed height entries remain and corrupt averageHeight (e.g., uniform ~44pt heights pulling average down when new variable-height data averages ~80pt)
- Fix: detect in body prepass and call `heightIndex.invalidateAll()` before any new heights are recorded

### SwiftUI LazyVStack materialization is non-deterministic
- After setContentOffset, SwiftUI takes variable time (100-500ms) to materialize content at the new position
- Sometimes 250ms is enough, sometimes it isn't — no reliable signal for "layout complete"
- Result for variable heights: probe-align gets within ~10-60 items in 2/3 of runs, but occasionally 300+ items away
- Uniform heights work perfectly every time (proportional estimate is exact when all items are same height)
- This is a **fundamental LazyVStack limitation** — documented, not fixable. UICollectionView backend solves this.

### Probe correction strategy
- Using `(contentSize/totalItems) * delta` for correction jumps is more reliable than `avgHeight * delta`
- The per-item proportional offset uses the same ratio as the initial estimate, maintaining consistency
- 3 passes with 250ms delay is the sweet spot — more passes rarely help due to materialization non-determinism

### Debug testing infrastructure
- `xcrun simctl launch --console-pty` with file redirect captures print() output from simulator
- NSLog from framework code is unreliable in system log capture
- Bundle ID must be read from built .app Info.plist, not assumed

---

## Why UICollectionView Would Be Better (Future Reference)

### The fundamental problem with LazyVStack

LazyVStack is a **black box**. SwiftUI controls when views materialize, when preferences propagate, and when layout settles. We have no guaranteed callback for "layout is done." Every workaround (async hops, retry loops, snapshot overlays) exists because we're fighting the framework's timing.

### What UICollectionView gives you that LazyVStack doesn't

1. **`scrollToItem(at:at:animated:)`** — works regardless of whether the cell exists. The layout engine owns the estimated sizes and can calculate the scroll destination internally.

2. **`estimatedItemSize` + `preferredLayoutAttributesFitting(_:)`** — Apple's own estimate→correct pipeline, but handled end-to-end within one layout engine. No async hops, no preference timing.

3. **Synchronous layout control** — `layoutIfNeeded()` on a collection view flushes ALL pending layout including cell sizing. On LazyVStack, `layoutIfNeeded()` flushes UIKit layout but SwiftUI preference propagation happens later.

4. **`performBatchUpdates`** — atomic data mutations with animation. No need for `wasPinnedBeforeCountChange` hacks or `autoScrollPending` flags.

5. **Delegate callbacks** — `scrollViewDidScroll`, `scrollViewDidEndScrollingAnimation`, `willDisplay cell` — precise, synchronous, deterministic. No preference key timing uncertainty.

6. **Cell reuse pool** — proven recycling mechanism vs. LazyVStack's opaque virtualization.

### What you'd lose

1. **SwiftUI-native NavigationStack integration** — large title collapse/expand, keyboard avoidance, safe area behavior all work automatically with ScrollView. With UICollectionView you'd reimplement these.

2. **SwiftUI view composition** — row content is currently a `@ViewBuilder` closure. With UICollectionView, each row would be a `UIHostingConfiguration` cell. This works (iOS 16+) but has cold-cell preparation cost during fast scroll (benchmark, not guaranteed problem per Apple WWDC22 guidance).

3. **The existing architecture** — every feature we've built (underflow anchoring, prepend correction, auto-scroll, keyboard handling) would need reimplementation.

4. **Simplicity** — the current codebase is ~450 lines of Swift. A UICollectionView backend would likely be 1500+.

### When to consider the switch

- If the probe-align approach has persistent visual artifacts that can't be masked
- If a consumer needs guaranteed <1 frame scroll-to-ID for extreme variable heights
- If Apple breaks the UIScrollView bridge in a future iOS version
- If the library needs to support edit/delete/reorder (UICollectionView has these built in)

### The hybrid path

Keep LazyVStack as the default. Add UICollectionView as an opt-in backend behind a config flag. Both backends implement the same `ChatViewportController` protocol. This is the simplex-chat approach — they have both SwiftUI and UIKit chat views.
