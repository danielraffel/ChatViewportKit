# Known Limitations

## Prepend requires `prepareToPrepend()`

The host must call `controller.prepareToPrepend()` before inserting items at the beginning of the data array. Without this call, the viewport may jump because the framework cannot distinguish a prepend from other data mutations.

## Prepend offset correction uses a short delay

After prepending, the offset correction runs on the next run loop iteration (`DispatchQueue.main.async`). This means there may be 1-2 frames where the viewport shows the wrong position before snapping to the correct spot. In practice, this is imperceptible.

## UIScrollView bridge is private and fragile

The framework uses a private UIViewRepresentable to find the hosting UIScrollView by traversing the view hierarchy. This works on iOS 16-18 but could break if Apple changes the SwiftUI-UIKit bridge internals. The bridge is only used for prepend offset correction; all other functionality uses pure SwiftUI APIs.

## `scrollTo` fails for items far from viewport

SwiftUI's `ScrollViewReader.scrollTo()` can fail silently when the target item is more than ~15-20 positions from the current render window in a LazyVStack. The framework works around this for prepend scenarios using the UIScrollView bridge, but `controller.scrollTo(id:)` may fail for arbitrary IDs in very large lists if the target is far from the current position.

## Data must have stable IDs

The data passed to ChatViewport must use stable, unique IDs (e.g., UUIDs). Using array indices or other unstable identifiers will break animations, scroll position preservation, and prepend detection.

## iOS 16+ only

The framework targets iOS 16+ for `ScrollView` and `LazyVStack` behavior. Some behaviors (like `onChange` closure semantics) differ between iOS 16 and 17+.

## No built-in keyboard handling

ChatViewportKit does not manage keyboard avoidance or composer layout. This is by design — the host app should compose the viewport with a composer view in a VStack, and SwiftUI's standard keyboard avoidance handles the rest.

## Performance at extreme scale

While tested at 10,000 rows, LazyVStack's content size estimation becomes less accurate at very large counts (50,000+). This can cause slight jitter during rapid scrolling at extreme scale.
