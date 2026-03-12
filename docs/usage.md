# ChatViewportKit Usage Guide

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

## Core Components

### ChatViewport

The main view. Generic over your data type, ID type, and row content.

```swift
// With Identifiable data (ID inferred)
ChatViewport(messages, controller: controller) { message in
    MessageRow(message: message)
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
    MessageRow(message: message)
}
```

### ChatViewportController

Provides imperative control and state observation.

```swift
@StateObject private var controller = ChatViewportController<UUID>()

// Scroll commands
controller.scrollToBottom()
controller.scrollToTop()
controller.scrollTo(id: someID, anchor: .center)

// State observation
controller.isPinnedToBottom  // Bool
controller.mode              // ViewportMode<ID>
controller.topVisibleItemID  // ID?

// Callback
controller.onBottomPinnedChanged = { isPinned in
    // Show/hide "jump to latest" button
}
```

### Prepending Data

Before inserting items at the beginning of your array, call `prepareToPrepend()`:

```swift
controller.prepareToPrepend()
messages.insert(contentsOf: olderMessages, at: 0)
```

This freezes the scroll anchor so the viewport doesn't jump when new items appear above.

### Configuration

```swift
ChatViewportConfiguration(
    spacing: 8,              // Spacing between rows (default: 8)
    bottomPinThreshold: 50,  // Distance from bottom to consider "pinned" (default: 50)
    topLoadTriggerOffset: 100, // Distance from top to trigger load-more (default: 100)
    showsIndicators: true    // Show scroll indicators (default: true)
)
```

## Architecture

- **LazyVStack** renders only visible rows — O(1) scroll performance at any count
- **Bottom anchoring** via `.frame(minHeight: viewportHeight, alignment: .bottom)` — no scroll-on-appear hack
- **Scroll position preservation** on prepend via UIScrollView contentOffset bridge
- **Mode state machine**: `initialBottomAnchored` → `pinnedToBottom` ↔ `freeBrowsing`
- Works inside `NavigationStack` with native top blur preserved

## Integration Pattern

ChatViewportKit is designed to be composed with your app's UI, not to own it:

```swift
NavigationStack {
    VStack(spacing: 0) {
        ChatViewport(messages, controller: controller) { msg in
            MessageBubble(message: msg)
        }

        // Composer is YOUR view, outside the viewport
        HStack {
            TextField("Message", text: $text)
            Button("Send") { sendMessage() }
        }
        .padding()
    }
}
```

Keyboard avoidance, composer layout, and navigation chrome are handled by SwiftUI's standard layout system.
