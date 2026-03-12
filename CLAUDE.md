# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChatViewportKit is a reusable SwiftUI bottom-anchored chat viewport component. Not just a "chat scroll view" — it's a viewport invariants engine that preserves competing truths (bottom pinning, stable history, anchor restoration) while content, size, and navigation chrome change.

The component should serve: AI streaming conversations, activity feeds, event timelines, log consoles, comments/threads, and any bottom-aware transcript UI.

## Design Decision History

Two architectural approaches were reviewed:

1. **v1 (ai/review.txt)**: UICollectionView-based engine. Rejected as primary plan — doesn't satisfy LazyVStack hard requirement. Kept as reference for invariant-driven thinking and state machine design.
2. **v2 (ai/review-v2.txt)**: ScrollView + LazyVStack first. **This is the accepted plan.** Private UIScrollView bridge planned for Phase 3 pixel-precise anchor correction only.
3. **Review (ai/review-v2-claude.txt)**: Design-level approved, implementation conditionally approved pending Phase 0 feasibility proof.

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

## Tracking Docs

- **docs/work-items.md** — source of truth for all implementation progress (Phases 0-5). Read at start of every iteration.
- **docs/learnings.md** — development discoveries, gotchas, performance findings. Check before starting any work.
- **ai/ralph-loop.md** — ralph-loop automation prompt for driving implementation.

## Tooling

- **xcodebuildmcp** (XcodeBuildMCP CLI): Build, test, and run in iOS simulator. Primary verification method.
- **sosumi MCP**: Apple documentation lookups — ScrollView, LazyVStack, ScrollViewReader, NavigationStack, preference keys, UIScrollView bridging.
- **/codex**: Parallel research tasks. Do NOT delegate simulator testing to Codex.

## Key Technical Concepts

- **Underflow anchoring**: `topFill = max(0, viewportHeight - contentHeight)` — a real animatable filler view
- **Underfill-to-overflow transition**: Animate filler shrink and row insertion in one transaction
- **Anchor snapshots**: Capture visible item ID + offset before data changes, restore after layout settles
- **Update pipeline**: Classify update → capture anchor → apply data → let layout settle → restore anchor → animate → recompute mode (the architectural spine — every mutation flows through it)
- **Measurement regime**: Total content height only while underfilled; after overflow, rely on visible-row frames and bottom distance

## Phased Build Plan (sequential, no skipping)

- **Phase 0**: Feasibility spike — prove hard requirements. THREE GATE TESTS must pass: (1) underfill→overflow transition smooth, (2) prepend no jump, (3) async height change no disturbance. If gates fail: increase UIKit assist, don't abandon SwiftUI component.
- **Phase 1**: Reusable component skeleton with full generic API
- **Phase 2**: Bottom pin detection and append animation
- **Phase 3**: Position preservation with private UIScrollView offset bridge
- **Phase 4**: NavigationStack, keyboard/composer, accessibility
- **Phase 5**: Packaging, performance validation, Transcript Lab demo, documentation

## Target

- iOS 16+ (UIHostingConfiguration compatibility for Phase 3 bridge)
- Test on iOS 16, 17, 18 simulators when behavior differs across versions
