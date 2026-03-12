import SwiftUI

/// The current scroll mode of the viewport, used to make update behavior deterministic.
public enum ViewportMode<ID: Hashable>: Equatable {
    /// Initial state: content is bottom-anchored via layout, no scrolling has occurred.
    case initialBottomAnchored
    /// User is at the bottom — new appends should auto-scroll to follow.
    case pinnedToBottom
    /// User has scrolled away from the bottom — appends should NOT move the viewport.
    case freeBrowsing(anchor: AnchorSnapshot<ID>?)
    /// A programmatic scroll is in progress.
    case programmaticScroll(target: ScrollTarget<ID>)
    /// Data changed and we're restoring the anchor position.
    case correctingAfterDataChange(anchor: AnchorSnapshot<ID>)
}

/// A snapshot of the current visible anchor, used for position restoration.
public struct AnchorSnapshot<ID: Hashable>: Equatable {
    public let id: ID
    public let distanceFromViewportTop: CGFloat
    public let distanceFromBottom: CGFloat

    public init(id: ID, distanceFromViewportTop: CGFloat, distanceFromBottom: CGFloat) {
        self.id = id
        self.distanceFromViewportTop = distanceFromViewportTop
        self.distanceFromBottom = distanceFromBottom
    }
}

/// A target for programmatic scrolling.
public enum ScrollTarget<ID: Hashable>: Equatable {
    case bottom
    case top
    case id(ID, anchor: UnitPoint)

    public static func == (lhs: ScrollTarget, rhs: ScrollTarget) -> Bool {
        switch (lhs, rhs) {
        case (.bottom, .bottom): return true
        case (.top, .top): return true
        case let (.id(lID, lAnchor), .id(rID, rAnchor)):
            return lID == rID && lAnchor == rAnchor
        default: return false
        }
    }
}
