# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChatViewportKit is a reusable SwiftUI bottom-anchored chat viewport component with two independent backends. Not just a "chat scroll view" — it's a viewport invariants engine that preserves competing truths (bottom pinning, stable history, anchor restoration) while content, size, and navigation chrome change.

The component should serve: AI streaming conversations, activity feeds, event timelines, log consoles, comments/threads, and any bottom-aware transcript UI.

## Architecture

Three Swift package modules — clean isolation:

- **ChatViewportCore** — Shared protocol, config, mode enum (~100 lines). No UIKit dependency.
- **ChatViewportSwiftUI** — LazyVStack backend with height index + probe-align engine. Imports Core.
- **ChatViewportUIKit** — UICollectionView backend with diffable data source. Imports Core only. Does NOT import ChatViewportSwiftUI.

```swift
// SwiftUI backend (most apps):
import ChatViewportSwiftUI  // or import ChatViewportKit (compatibility)

// UIKit backend (guaranteed scrollTo precision):
import ChatViewportUIKit
```

### When to Use Which

- **ChatViewportSwiftUI**: Most apps. Pure SwiftUI, NavigationStack integration, keyboard handling automatic, lighter code. scrollTo(id:) uses height estimation + probe-align for far targets.
- **ChatViewportUIKit**: Apps needing guaranteed scrollTo precision with highly variable heights, or apps needing cell reuse control. Trade: more manual keyboard/nav handling.

## Hard Requirements

1. Bottom-anchor initial underfilled content without startup jump
2. Expose `scrollToBottom`, `scrollToTop`, `scrollTo(id:)` via controller
3. No inverse scrolling or rotation hacks
4. Work inside `NavigationStack` preserving native top blur
5. Generic and reusable — not chat-message-specific
6. Prepend and height changes do not visibly jump the viewport

## Performance Targets (enforced, not aspirational)

- 60fps scroll at 5000+ rows with mixed heights
- Append burst of 50 messages: no frame drops while pinned
- Prepend of 50 messages: anchor restoration within one frame
- Keyboard show/hide + simultaneous append: no dropped frames

## API Shape

```swift
// Shared (ChatViewportCore)
protocol ChatViewportControllerProtocol: ObservableObject
protocol ChatViewportDiagnostics
struct ChatViewportConfiguration
enum ViewportMode<ID: Hashable>

// SwiftUI backend
struct ChatViewport<Data, ID, RowContent>: View
final class ChatViewportController<ID: Hashable>: ObservableObject

// UIKit backend
struct UKChatViewport<Data, ID, RowContent>: UIViewRepresentable
final class UKChatViewportController<ID: Hashable>: ObservableObject
```

## Build & Run

```bash
# Build example app for simulator
xcodebuildmcp simulator build --scheme ChatViewportKitExample --project-path ./Example/ChatViewportKitExample.xcodeproj --simulator-name "iPhone 17 Pro"

# Build and run
xcodebuildmcp simulator build-and-run --scheme ChatViewportKitExample --project-path ./Example/ChatViewportKitExample.xcodeproj --simulator-name "iPhone 17 Pro"

# Build framework only (note: iOS-only, use xcodebuild not swift build)
xcodebuildmcp swift-package build --package-path .
```

## Key Technical Concepts

### SwiftUI Backend
- **Underflow anchoring**: `.frame(minHeight:, alignment: .bottom)` — layout-based, not scroll-on-appear
- **Height Index + Probe-Align**: For scrollTo(id:) to far/unmaterialized items. Proportional estimation, snapshot overlay, iterative refinement.
- **UIScrollView bridge**: Pixel-precise offset correction for prepend and keyboard
- **Anchor snapshots**: Capture visible item ID + offset before data changes, restore after layout

### UIKit Backend
- **UKBottomAnchoredLayout**: UICollectionViewFlowLayout subclass pushing underfilled content to bottom
- **NSDiffableDataSourceSnapshot**: Bridge from RandomAccessCollection to collection view
- **UIHostingConfiguration**: SwiftUI row content in self-sizing cells
- **Native scrollToItem**: No probe-align needed — layout engine handles estimates

## Target

- iOS 16+
