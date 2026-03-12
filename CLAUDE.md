# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChatViewportKit is a reusable SwiftUI bottom-anchored chat viewport component. Not just a "chat scroll view" — it's a viewport invariants engine that preserves competing truths (bottom pinning, stable history, anchor restoration) while content, size, and navigation chrome change.

The component should serve: AI streaming conversations, activity feeds, event timelines, log consoles, comments/threads, and any bottom-aware transcript UI.

## Architecture

ScrollView + LazyVStack is the render engine. A private UIScrollView bridge (Phase 3) provides pixel-precise anchor correction for prepend operations only — all other functionality uses pure SwiftUI APIs.

## Hard Requirements

1. `LazyVStack` is the actual render stack
2. Bottom-anchor initial underfilled content without startup jump (layout-based topFill, not scroll-on-appear)
3. Expose `scrollToBottom`, `scrollToTop`, `scrollTo(id:)` via `ChatViewportController`
4. No inverse scrolling or rotation hacks
5. Animate tail insertions from bottom in both underfilled and overflowing states
6. Work inside `NavigationStack` preserving native top blur
7. Generic and reusable — not chat-message-specific
8. Prepend and height changes do not visibly jump the viewport

## Performance Targets (enforced, not aspirational)

- 60fps scroll at 5000+ rows with mixed heights
- Append burst of 50 messages: no frame drops while pinned
- Prepend of 50 messages: anchor restoration within one frame
- Keyboard show/hide + simultaneous append: no dropped frames
- Measured with Instruments / frame time tracking — numbers, not vibes

## Accepted API Shape

```swift
struct ChatViewport<Data, ID, RowContent>: View
final class ChatViewportController<ID: Hashable>: ObservableObject
struct ChatViewportConfiguration
enum ViewportMode<ID: Hashable>  // initialBottomAnchored, pinnedToBottom, freeBrowsing, programmaticScroll, correctingAfterDataChange
struct AnchorSnapshot<ID: Hashable>
```

## Swift Package Structure

- `ChatViewportKit` — the reusable framework (ChatViewport, controller, configuration, state machine, anchor engine)
- `ChatViewportKitExample` — Transcript Lab demo app (proves every capability)
- Clean module boundary: no demo code in framework, no framework internals leaked

## Build & Run

```bash
# Build for simulator
xcodebuildmcp simulator build-sim --scheme ChatViewportKitExample --project-path ./Example/ChatViewportKitExample.xcodeproj --simulator-name "iPhone 16 Pro"

# Build and run
xcodebuildmcp simulator build-run-sim --scheme ChatViewportKitExample --project-path ./Example/ChatViewportKitExample.xcodeproj --simulator-name "iPhone 16 Pro"

# Build framework only
xcodebuildmcp swift-package build --package-path .
```

## Key Technical Concepts

- **Underflow anchoring**: `topFill = max(0, viewportHeight - contentHeight)` — a real animatable filler view
- **Underfill-to-overflow transition**: Animate filler shrink and row insertion in one transaction
- **Anchor snapshots**: Capture visible item ID + offset before data changes, restore after layout settles
- **Update pipeline**: Classify update → capture anchor → apply data → let layout settle → restore anchor → animate → recompute mode (the architectural spine — every mutation flows through it)
- **Measurement regime**: Total content height only while underfilled; after overflow, rely on visible-row frames and bottom distance

## Target

- iOS 16+
