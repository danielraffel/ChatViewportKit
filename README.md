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

## Two Backends

ChatViewportKit offers two independent scroll backends behind a shared protocol:

### ChatViewportSwiftUI (default)

The render engine is a standard SwiftUI `ScrollView` + `LazyVStack` — no inverted scroll views, no rotation hacks. Content is bottom-anchored using `.frame(minHeight: viewportHeight, alignment: .bottom)`. A lightweight `UIScrollView` bridge provides pixel-precise offset correction for prepends and reliable `scrollTo(id:)` via a height-index + probe-align engine.

**Best for**: Most apps. Pure SwiftUI, NavigationStack integration, keyboard handling automatic.

### ChatViewportUIKit

A `UICollectionView` backend wrapped in `UIViewRepresentable`. Uses `UICollectionViewFlowLayout` subclass for bottom-anchoring, `NSDiffableDataSourceSnapshot` for data management, and `UIHostingConfiguration` for SwiftUI row content.

**Best for**: Apps needing guaranteed `scrollTo(id:)` precision with highly variable heights, or apps that need cell reuse control.

### Shared Architecture

Both backends conform to `ChatViewportControllerProtocol` and a state machine (`ViewportMode`) drives behavior deterministically:
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

Three library products available:
- `ChatViewportKit` — Compatibility alias, re-exports `ChatViewportSwiftUI`
- `ChatViewportSwiftUI` — LazyVStack backend
- `ChatViewportUIKit` — UICollectionView backend

Requires iOS 16+.

## Quick Start

### SwiftUI Backend

```swift
import ChatViewportKit  // or import ChatViewportSwiftUI

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

### UIKit Backend

```swift
import ChatViewportUIKit

struct MyChatView: View {
    @StateObject private var controller = UKChatViewportController<UUID>()
    @State private var messages: [Message] = []

    var body: some View {
        UKChatViewport(messages, controller: controller) { message in
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
controller.bounceToTop()  // Force nav bar re-render after title display mode change

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

Keyboard avoidance and composer layout are handled by SwiftUI's standard layout system — ChatViewportKit doesn't interfere with any of it. When the keyboard appears or disappears while pinned to the bottom, the viewport automatically scrolls to keep the last message visible.

## Example App

The repo includes an example app (`Example/`) with both backends. A picker root view lets you navigate into either backend's lab view — **SwiftUI Backend** (LazyVStack) or **UIKit Backend** (UICollectionView). Both share the same controls and data model.

Each backend exercises every capability:

**Append controls**: Add 1, 3, 10, 50, 5,000, or 10,000 messages. Burst-append 20 messages with 50ms spacing to simulate streaming.

**Prepend controls**: Insert 1, 5, 10, or 50 older messages at the top — scroll position stays put.

**Scroll controls**: Jump to bottom, jump to top, scroll to middle by ID.

**Height mutation**: **Expand** sets the last message to 200pt tall (simulates a card or embed loading in-place). **Grow** picks a random message and increases its height to 150pt after a 0.5s delay (simulates an image finishing download — tests that async height changes don't jump the viewport).

**Dynamic type**: Toggle between standard and accessibility-XXL text sizes mid-browse.

**Navigation modes**: **→ Title** / **→ Inline** button switches between `.large` and `.inline` navigation bar title display modes. Scrolls to absolute top on toggle so the large title expands immediately. Tests that the viewport works correctly with both styles and that the iOS nav bar blur effect is preserved.

**Composer**: Multiline text field with send button. Keyboard show/hide keeps the last message visible. Swipe down on the composer or tap the message area to dismiss the keyboard.

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

Both backends handle 10,000+ rows at 60fps. Lazy rendering means only visible rows (~11 at a time) are materialized, so scroll performance is O(1) regardless of total count.

The example app's **Stress** button runs a timed sequence: load 10K variable-height rows, scroll to middle, append 50, prepend 50, burst-append 20. Timings are logged via `NSLog` with `[STRESS]` tags and displayed in the debug HUD. You can reproduce these on your own hardware by running the stress test in either backend.

Data mutation times measured on the SwiftUI backend (iPhone 16 Pro simulator, `CFAbsoluteTimeGetCurrent` wall-clock):

| Operation | Time |
|---|---|
| Load 10K messages | ~5ms |
| Append 50 at 10K | ~8ms |
| Prepend 50 at 10K | ~0.85ms |
| Burst append (20 at 50ms) | ~0.4ms each |

These measure array mutation and SwiftUI state update time, not rendering. Actual frame times depend on device, row complexity, and whether animations are active. Both backends stay well under the 16.67ms frame budget for typical operations.

## Known Limitations

### Both Backends
- **`prepareToPrepend()` is required before prepends.** The framework can't distinguish a prepend from other mutations without this signal.
- **Data must have stable IDs.** Use UUIDs or other stable identifiers — not array indices.
- **iOS 16+ only.**

### SwiftUI Backend
- **The UIScrollView bridge is private.** It traverses the view hierarchy to find the hosting UIScrollView. This works on iOS 16–18 but could break if Apple changes SwiftUI internals.
- **`scrollTo(id:)` for variable heights.** The probe-align engine works perfectly for uniform heights. For highly variable heights (40-400pt), it typically lands within 10-60 items of the target due to LazyVStack materialization non-determinism. Use the UIKit backend if pixel-perfect scrollTo is critical.

### UIKit Backend
- **Row content restrictions.** Views containing `UIViewControllerRepresentable` cannot be used in cells. `GeometryReader` in cells may cause sizing loops.
- **NavigationStack large title.** Use `bounceToTop()` after toggling between `.large` and `.inline` display modes to force the nav bar to re-render.
- **Keyboard handling.** Uses `keyboardDismissMode = .interactive` for swipe-to-dismiss. When pinned to bottom, the viewport automatically scrolls to keep the last message visible when the keyboard appears. Content inset adjustment relies on SwiftUI's container resizing.

## License

MIT
