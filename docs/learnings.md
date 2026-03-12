# ChatViewportKit Development Learnings

Track non-obvious discoveries, gotchas, and solutions found during implementation.
Check this file before starting any work item.

---

## Architecture Decisions

- v1 approach (UICollectionView engine) was rejected — LazyVStack is a hard requirement
- v2 approach (ScrollView + LazyVStack) is the accepted plan
- Private UIScrollView bridge is planned for Phase 3 ONLY for pixel-precise offset correction
- The bridge must NOT replace the SwiftUI render tree or expose UIKit to consumers

## Known SwiftUI Scroll Challenges

(Add learnings here as they are discovered during implementation)

## Performance Notes

(Add profiling results and optimization learnings here)

## Apple Documentation References

(Add links to relevant Apple docs discovered via sosumi MCP here)
