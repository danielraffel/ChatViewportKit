# ChatViewportKit

A SwiftUI component for bottom-anchored scrolling content. The kind you see in chat apps, AI conversations, log consoles, and activity feeds.

ChatViewportKit solves the hard viewport problems that come with these UIs: content should start at the bottom, new messages should auto-scroll when you're at the bottom but not when you're reading history, prepending older messages shouldn't jump the viewport, and height changes in visible rows shouldn't disturb your reading position. All of this needs to work at 60fps with thousands of rows.

## The Problem

Building a chat-style scrolling view in SwiftUI is deceptively hard. The basic `ScrollView` + `LazyVStack` combo gives you lazy rendering, but you're left to solve:

- **Bottom anchoring**: Content should start at the bottom of the viewport when there are only a few messages, with no visible jump on first render.
- **Auto-follow on append**: When the user is at the bottom, new messages should scroll into view. When they've scrolled up to read history, new messages should appear silently without moving the viewport.
- **Prepend without jump**: Loading older messages at the top should not shift what's currently on screen.
- **Height changes without jump**: Images loading, text expanding, or dynamic type changes should not disturb the reading position.
- **Smooth animations**: Messages should animate in from the bottom, and the transition from underfilled (fewer messages than the screen) to overflowing should be seamless.

ChatViewportKit handles all of this with a single drop-in view.

## How It Works

The render engine is a standard SwiftUI `ScrollView` + `LazyVStack` - no `UICollectionView` wrapper, no inverted scroll views, no rotation hacks. Content is bottom-anchored using `.frame(minHeight: viewportHeight, alignment: .bottom)` on the `LazyVStack`, which pushes rows to the bottom when content is shorter than the viewport and grows naturally when it overflows.

A lightweight `UIScrollView` bridge (invisible to consumers) provides direct `contentOffset` access for pixel-precise position correction after prepends. This bridge only reads and writes the scroll offset — it never touches the content, delegate, or layout properties of the underlying scroll view.

A state machine (`ViewportMode`) drives behavior deterministically:
- `initialBottomAnchored` — first render, content at bottom
- `pinnedToBottom` — user is at the bottom, auto-follow is active
- `freeBrowsing` — user scrolled away, auto-follow is off
- `programmaticScroll` — a scroll command is in flight
- `correctingAfterDataChange` — restoring position after a data mutation

## Installation

Add ChatViewportKit as a Swift Package dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/danielraffel/ChatViewportKit.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies, paste the repository URL.

Requires iOS 16+.

## Quick Start

```swift
import ChatViewportKit

struct MyChatView: View {
    @StateObject private var controller = ChatViewportController<UUID>()
    @State private var messages: [Message] = []

    var body: some View {
        ChatViewport(messages, controller: controller) { message in
            Text(message.text)
                .padding()
        }
    }
}
```

Your data type just needs to conform to `Identifiable` (or you can pass an explicit `id:` key path).

## API

### ChatViewport

The main view. Generic over your data type, ID type, and row content.

```swift
// With Identifiable data
ChatViewport(messages, controller: controller) { message in
    MessageBubble(message: message)
}

// With explicit ID key path
ChatViewport(items, id: \.itemID, controller: controller) { item in
    ItemRow(item: item)
}

// With configuration
ChatViewport(
    messages,
    controller: controller,
    configuration: ChatViewportConfiguration(
        spacing: 8,
        bottomPinThreshold: 50,
        showsIndicators: true
    )
) { message in
    MessageBubble(message: message)
}
```

### ChatViewportController

Imperative control and state observation.

```swift
@StateObject private var controller = ChatViewportController<UUID>()

// Scroll commands
controller.scrollToBottom()
controller.scrollToTop()
controller.scrollTo(id: someMessageID, anchor: .center)

// State
controller.isPinnedToBottom   // true when at the bottom
controller.mode               // current ViewportMode
controller.topVisibleItemID   // ID of the topmost visible row

// Callback for showing/hiding a "jump to latest" button
controller.onBottomPinnedChanged = { isPinned in
    showJumpButton = !isPinned
}
```

### Prepending Data

Before inserting items at the beginning of your array, call `prepareToPrepend()`:

```swift
controller.prepareToPrepend()
messages.insert(contentsOf: olderMessages, at: 0)
```

This freezes the scroll anchor so the viewport stays on the same content while new items appear above.

### Configuration

```swift
ChatViewportConfiguration(
    spacing: 8,                // Space between rows (default: 8)
    bottomPinThreshold: 50,    // Distance from bottom to count as "pinned" (default: 50)
    topLoadTriggerOffset: 80,  // Distance from top to trigger load-more (default: 80)
    showsIndicators: true      // Show scroll indicators (default: true)
)
```

## Integration Pattern

ChatViewportKit owns the scrolling viewport. Your app owns everything else — the composer, the navigation chrome, the message styling:

```swift
NavigationStack {
    VStack(spacing: 0) {
        ChatViewport(messages, controller: controller) { msg in
            MessageBubble(message: msg)
        }

        HStack {
            TextField("Message", text: $text)
            Button("Send") { sendMessage() }
        }
        .padding()
    }
}
```

Keyboard avoidance, composer layout, and navigation bar behavior are all handled by SwiftUI's standard layout system — ChatViewportKit doesn't interfere with any of it.

## Example App

The repo includes a **Transcript Lab** example app (`Example/`) that exercises every capability:

**Append controls**: Add 1, 3, 10, 50, 5,000, or 10,000 messages. Burst-append 20 messages with 50ms spacing to simulate streaming.

**Prepend controls**: Insert 1, 5, 10, or 50 older messages at the top — scroll position stays put.

**Scroll controls**: Jump to bottom, jump to top, scroll to middle by ID.

**Height mutation**: **Expand** sets the last message to 200pt tall (simulates a card or embed loading in-place). **Grow** picks a random message and increases its height to 150pt after a 0.5s delay (simulates an image finishing download — tests that async height changes don't jump the viewport).

**Dynamic type**: Toggle between standard and accessibility-XXL text sizes mid-browse.

**Navigation modes**: **Nav Title** / **Nav Inline** button cycles between `.large` and `.inline` navigation bar title display modes — scrolls to top on toggle so you can see the change. Pull down slightly at the top to trigger the large title appearance (standard iOS behavior). Tests that the viewport works correctly with both styles and that the iOS nav bar blur effect is preserved.

**Composer**: Multiline text field with send button — keyboard show/hide doesn't break bottom pinning.

**Debug HUD**: Toggle with the **HUD** button in the toolbar. Live readout of message count, viewport mode, pinned state, top visible item, UIScrollView bridge status, and anchor freeze state.

To run it:

```bash
# Open in Xcode
open Example/ChatViewportKitExample.xcodeproj

# Or build from the command line
xcodebuild -project Example/ChatViewportKitExample.xcodeproj \
    -scheme ChatViewportKitExample \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    build
```

## Performance

Tested at 10,000 rows with mixed heights (every 3rd row has variable height):

| Operation | Time |
|---|---|
| Load 10K messages | 5ms |
| Append 50 at 10K | 8ms |
| Prepend 50 at 10K | 0.85ms |
| Burst append (20 at 50ms) | ~0.4ms each |

All operations are well under the 16.67ms frame budget for 60fps. `LazyVStack` renders only the visible rows (~11 at a time), so scroll performance is O(1) regardless of total count.

## Known Limitations

- **`prepareToPrepend()` is required before prepends.** The framework can't distinguish a prepend from other mutations without this signal.
- **The UIScrollView bridge is private.** It traverses the view hierarchy to find the hosting UIScrollView. This works on iOS 16–18 but could break if Apple changes SwiftUI internals. The bridge is used for prepend offset correction, reliable scroll-to-bottom (at any distance), and auto-scroll on append.
- **`scrollTo(id:)` has range limits.** SwiftUI's `ScrollViewReader` can fail for items far from the current render window in a `LazyVStack`. `scrollToBottom()` and `scrollToTop()` use the UIScrollView bridge and work reliably at any distance; `scrollTo(id:)` for arbitrary IDs is limited to ~15–20 positions from the current viewport.
- **Data must have stable IDs.** Use UUIDs or other stable identifiers — not array indices.
- **iOS 16+ only.**
- **No built-in keyboard handling.** By design — compose the viewport with your own composer view in a `VStack`, and SwiftUI handles the rest.

## License

MIT
