import SwiftUI

/// Configuration for a `ChatViewport`.
public struct ChatViewportConfiguration {
    public var spacing: CGFloat
    public var bottomPinThreshold: CGFloat
    public var topLoadTriggerOffset: CGFloat
    public var showsIndicators: Bool
    public var animateTailInsertions: Bool
    public var preservePositionOnPrepend: Bool
    public var preservePositionOnHeightChange: Bool

    public init(
        spacing: CGFloat = 8,
        bottomPinThreshold: CGFloat = 24,
        topLoadTriggerOffset: CGFloat = 80,
        showsIndicators: Bool = true,
        animateTailInsertions: Bool = true,
        preservePositionOnPrepend: Bool = true,
        preservePositionOnHeightChange: Bool = true
    ) {
        self.spacing = spacing
        self.bottomPinThreshold = bottomPinThreshold
        self.topLoadTriggerOffset = topLoadTriggerOffset
        self.showsIndicators = showsIndicators
        self.animateTailInsertions = animateTailInsertions
        self.preservePositionOnPrepend = preservePositionOnPrepend
        self.preservePositionOnHeightChange = preservePositionOnHeightChange
    }
}
