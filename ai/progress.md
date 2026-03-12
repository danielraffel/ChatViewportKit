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
- [ ] 23. Create ChatViewportUIKit target
- [ ] 24. Create UKChatViewportController
- [ ] 25. Create UKChatViewport (UIViewRepresentable)
- [ ] 26. Create UKHostingCell
- [ ] 27. Create UKBottomAnchoredLayout
- [ ] 28. Create UKDataSource
- [ ] 29. Verify basic rendering

## Phase B2: Scroll Behavior
- [ ] 30. Bottom-pin detection
- [ ] 31. Auto-scroll on append
- [ ] 32. Prepend without jump
- [ ] 33. scrollTo(id:) via scrollToItem
- [ ] 34. scrollToTop/Bottom
- [ ] 35. Verify all commands

## Phase B3: Layout & Chrome
- [ ] 36. Spacing support
- [ ] 37. Keyboard handling
- [ ] 38. Scroll indicators
- [ ] 39. Append animation
- [ ] 40. Verify visual quality

## Phase B4: Edge Cases
- [ ] 41. Height mutations
- [ ] 42. Dynamic Type
- [ ] 43. onBottomPinnedChanged
- [ ] 44. estimatedRowHeight config
- [ ] 45. Verify parity

## Phase B5: Collection View Testing
- [ ] 46. 10K rows performance
- [ ] 47. scrollTo accuracy
- [ ] 48. Variable heights
- [ ] 49. Burst + prepend
- [ ] 50. Verify 60fps

## Phase C: Example App
- [ ] 51. Keep TranscriptLabView as-is
- [ ] 52. Create UKTranscriptLabView
- [ ] 53. Create BackendComparisonView
- [ ] 54. Shared LabMessage model
- [ ] 55. Jump-to-# in both
- [ ] 56. Variable-height toggle in both
- [ ] 57. Accuracy readout in both
- [ ] 58. Identical button bars
- [ ] 59. Root view with tabs
- [ ] 60. Both backends testable

## Phase D: Documentation
- [ ] 61. README — two-module architecture
- [ ] 62. "When to use which" guide
- [ ] 63. Comparison table
- [ ] 64. Code examples per module
- [ ] 65. ChatViewportKit docs update
- [ ] 66. ChatViewportCV docs (new)
- [ ] 67. known-limitations.md per backend
- [ ] 68. CLAUDE.md update
- [ ] 69. API consistency review
- [ ] 70. Commit and push
