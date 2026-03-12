import SwiftUI

/// The current scroll mode of the viewport, used to make update behavior deterministic.
public enum ViewportMode<ID: Hashable>: Equatable {
    case initialBottomAnchored
    case pinnedToBottom
    case freeBrowsing(anchor: AnchorSnapshot<ID>)
    case programmaticScroll(target: ScrollTarget<ID>)
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
