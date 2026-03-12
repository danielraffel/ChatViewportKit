"You are building ChatViewportKit — a reusable SwiftUI bottom-anchored chat viewport component — from design spec through fully packaged Swift framework with demo app.

GOVERNING RULES:
* The file CLAUDE.md defines architecture decisions, hard requirements, and accepted API shape. Read it at the start of EVERY iteration.
* All work happens on feature branches, never on main.
* Performance is a HARD requirement, not aspirational. 60fps scrolling at 5000+ rows. No frame drops on append/prepend bursts.
* You are building TWO things: a framework AND an example app that uses the framework to great effect.
* No inverse scrolling. No rotation hacks. No scroll-on-appear fudges. These are non-negotiable.

SOURCE OF TRUTH:
* docs/work-items.md defines all required work items and tracks progress across Phases 0-5.
* docs/learnings.md tracks development discoveries, gotchas, and performance findings.
* ai/review-v2.txt is the accepted architectural spec.
* ai/review-v2-claude.txt is the review tightening vague areas.

DESIGN SPECS (read these for context, do not modify):
* ai/review.txt — original v1 spec (rejected as primary, but useful for invariant-driven thinking and state machine design)
* ai/review-v2.txt — accepted v2 spec: ScrollView + LazyVStack first, private UIScrollView bridge Phase 3 only
* ai/review-v2-claude.txt — review identifying remaining risks and tightening exit criteria

TOOLS:
* Use xcodebuildmcp (XcodeBuildMCP CLI) for building, testing, and running in iOS simulator. This is how you verify everything works.
* Use sosumi MCP for Apple documentation lookups — ScrollView, LazyVStack, ScrollViewReader, NavigationStack, preference keys, UIScrollView bridging, etc.
* Use /codex for parallel research tasks (e.g., investigating SwiftUI scroll internals, finding solutions to specific scroll behavior challenges).
* Do NOT delegate simulator testing to Codex (it cannot run xcodebuildmcp).

SWIFT PACKAGE STRUCTURE:
* Root: ChatViewportKit (Swift Package)
* Framework target: ChatViewportKit (the reusable component — ChatViewport, ChatViewportController, ChatViewportConfiguration, ViewportMode, AnchorSnapshot)
* Example target: ChatViewportKitExample (Transcript Lab demo app — proves every capability)
* Clean module boundary: no demo code in framework, no framework internals leaked to consumers

HARD REQUIREMENTS (from accepted spec):
1. LazyVStack is the actual render stack
2. Bottom-anchor initial underfilled content without startup jump (layout-based topFill)
3. Expose scrollToBottom, scrollToTop, scrollTo(id:) via ChatViewportController
4. No inverse scrolling or rotation hacks
5. Animate tail insertions from bottom in both underfilled and overflowing states
6. Work inside NavigationStack preserving native top blur
7. Generic and reusable — not chat-message-specific
8. Prepend and height changes do not visibly jump the viewport

PERFORMANCE TARGETS (enforced, not aspirational):
* 60fps scroll at 5000+ rows with mixed heights
* Append burst of 50 messages: no frame drops while pinned
* Prepend of 50 messages: anchor restoration within one frame
* Keyboard show/hide + simultaneous append: no dropped frames
* Measure with Instruments / frame time tracking — numbers, not vibes

THE THREE PHASE 0 GATE TESTS (from project owner):
These three must pass before moving past Phase 0. If they fail, increase private UIKit assist scope — do NOT abandon the SwiftUI-facing component:
1. Underfilled append looks smooth when it becomes overflowing
2. Prepend does not visually jump
3. Async height changes do not disturb the reading position

EXECUTION ORDER (STRICT — sequential, no skipping):
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Within each phase, work items are executed in numerical order. Do not advance to the next phase until ALL items in the current phase are done or blocked with documented reason.

PHASE 0 IS RUTHLESS:
Do not proceed past Phase 0 until the demo proves the three gate tests above. This is where the approach is validated or the fallback plan kicks in. Spend the time here.

EXAMPLE APP REQUIREMENTS (Transcript Lab):
The example app is as important as the framework. It must include:
* Controls: 1/5/50/5000 rows, append one, append burst, prepend older, jump to latest, jump to arbitrary ID, expand row to 5x height, async height growth, NavigationStack large/inline title modes, keyboard/composer demo
* Debug HUD: current ViewportMode, pinned-to-bottom state, first/last visible IDs, distance from bottom, last anchor snapshot, layout invalidation reason
* The demo is what proves the framework is real

CODEX DELEGATION:
* Use /codex for parallel research: SwiftUI scroll behavior, preference key patterns, UIScrollView introspection approaches, animation timing
* Use /codex for code review of implementation
* Do NOT delegate xcodebuildmcp operations or simulator testing to Codex

IMPLEMENTATION RULES:
* Start with the simplest approach that could work — do not over-engineer Phase 0
* Commit at meaningful checkpoints, not just at phase boundaries
* When something doesn't work as expected, add it to docs/learnings.md before trying the next approach
* If a SwiftUI API doesn't behave as documented, verify against Apple docs via sosumi before working around it
* The update pipeline (classify → capture anchor → apply data → settle → restore → animate → recompute mode) is the architectural spine — every mutation flows through it
* Test on multiple iOS versions via simulator (iOS 16, 17, 18) when behavior differs across versions

GIT DISCIPLINE:
* Commit at the end of EVERY iteration where changes were made
* Commits must be small, focused, and descriptive
* Do NOT push to remote unless explicitly asked
* Phase 0 work: feature/phase-0-spike branch
* Phase 1+: feature/phase-N-description branches (create as you enter each phase)

EACH ITERATION MUST:
1. Re-read CLAUDE.md
2. Re-read docs/work-items.md
3. Check docs/learnings.md for relevant prior discoveries
4. Identify the NEXT incomplete item following Execution Order
5. Switch to the correct branch
6. Implement it
7. Build and test via xcodebuildmcp — verify in simulator
8. If anything non-obvious was learned, add to docs/learnings.md
9. Commit changes
10. Update docs/work-items.md status ([ ] → [~] when starting, [~] → [x] when done, [!] if blocked)
11. Summarize what was done and what is next

COMPLETION CONDITION:
* docs/work-items.md has ZERO incomplete items across Phases 0-5
* All items marked [x] or [!] with documented blockers
* All phase exit gates pass
* Framework builds and runs on iOS 16+ simulator
* Example app demonstrates every hard requirement
* Performance targets met with measurements (not guesses)
* The 8 hard requirements all hold under stress testing

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: DONE

IF STUCK:
* After 5 iterations without progress on a VM task, switch to GitHub Actions CI as
alternative.
* After 10 iterations total without progress, document in docs/learnings.md" --completion-promise "DONE" --max-iterations 120