# Dual-Backend Implementation Progress

## Phase A1: Extract Shared Types into ChatViewportCore
- [x] 1. Create ChatViewportCore target in Package.swift
- [x] 2. Move ViewportMode, AnchorSnapshot, ScrollTarget, ChatViewportConfiguration to Core
- [x] 3. Create ChatViewportControllerProtocol + ChatViewportDiagnostics in Core
- [x] 4. Conform ChatViewportController to both protocols
- [x] 5. Rename ChatViewportKit target to ChatViewportSwiftUI + compatibility wrapper
- [x] 6. Verify everything builds and runs

## Phase A2: Height Index Foundation
- [x] 7. Create HeightIndex.swift
- [x] 8. Add heightIndex to ChatViewportController (plain property, not @Published)
- [x] 9. Wire height recording in existing GeometryReader (rule 6)
- [x] 10. Add invalidateAll() on viewport width change
- [x] 11. Verify builds and heights accumulate

## Phase A3: Probe-Align Engine
- [x] 12. Add scroll session state (plain properties)
- [x] 13. Add idScrollInFlight guard
- [x] 14. Implement snapshot overlay helper
- [x] 15. Implement probe-align with two async hops
- [x] 16. Wire scrollTo(id:) to new path
- [x] 17. Add cancellation on data change
- [x] 18. Verify scrollTo works

## Phase A4: LazyVStack Testing
- [x] 19. Test 10K → 5000 (warm + cold)
- [x] 20. Test variable heights
- [x] 21. Tune parameters
- [x] 22. Verify no flash, all behaviors intact

## Phase B1: UICollectionView Foundation
- [x] 23. Create ChatViewportUIKit target
- [x] 24. Create UKChatViewportController
- [x] 25. Create UKChatViewport (UIViewRepresentable)
- [x] 26. Create UKHostingCell
- [x] 27. Create UKBottomAnchoredLayout
- [x] 28. Create UKDataSource
- [x] 29. Verify basic rendering

## Phase B2: Scroll Behavior
- [x] 30. Bottom-pin detection
- [x] 31. Auto-scroll on append
- [x] 32. Prepend without jump
- [x] 33. scrollTo(id:) via scrollToItem
- [x] 34. scrollToTop/Bottom
- [x] 35. Verify all commands

## Phase B3: Layout & Chrome
- [x] 36. Spacing support
- [x] 37. Keyboard handling
- [x] 38. Scroll indicators
- [x] 39. Append animation
- [x] 40. Verify visual quality

## Phase B4: Edge Cases
- [x] 41. Height mutations
- [x] 42. Dynamic Type
- [x] 43. onBottomPinnedChanged
- [x] 44. estimatedRowHeight config
- [x] 45. Verify parity

## Phase B5: Collection View Testing
- [x] 46. 10K rows performance
- [x] 47. scrollTo accuracy
- [x] 48. Variable heights
- [x] 49. Burst + prepend
- [x] 50. Verify 60fps

## Phase C: Example App
- [x] 51. Keep TranscriptLabView as-is
- [x] 52. Create UKTranscriptLabView
- [x] 53. Create BackendComparisonView
- [x] 54. Shared LabMessage model
- [x] 55. Jump-to-# in both
- [x] 56. Variable-height toggle in both
- [x] 57. Accuracy readout in both
- [x] 58. Identical button bars
- [x] 59. Root view with tabs
- [x] 60. Both backends testable

## Phase D: Documentation
- [x] 61. README — two-module architecture
- [x] 62. "When to use which" guide
- [x] 63. Comparison table
- [x] 64. Code examples per module
- [x] 65. ChatViewportKit docs update
- [x] 66. ChatViewportCV docs (new)
- [x] 67. known-limitations.md per backend
- [x] 68. CLAUDE.md update
- [x] 69. API consistency review
- [x] 70. Commit and push
