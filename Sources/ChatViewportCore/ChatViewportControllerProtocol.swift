import SwiftUI

/// Base command surface — what consumers need to drive a chat viewport.
///
/// Both `ChatViewportController` (SwiftUI/LazyVStack backend) and
/// `UKChatViewportController` (UIKit/UICollectionView backend) conform to this.
/// Backend-specific extras (like `bounceToTop` on the SwiftUI controller)
/// stay on concrete types — they're not cross-backend concerns.
public protocol ChatViewportControllerProtocol: ObservableObject {
    associatedtype ID: Hashable

    /// The current viewport mode.
    var mode: ViewportMode<ID> { get }

    /// Whether the viewport is currently pinned to the bottom.
    var isPinnedToBottom: Bool { get }

    /// Callback when pinned-to-bottom state changes.
    var onBottomPinnedChanged: ((Bool) -> Void)? { get set }

    /// Scroll to the bottom of the content.
    func scrollToBottom(animated: Bool)

    /// Scroll to the top of the content.
    func scrollToTop(animated: Bool)

    /// Scroll to a specific item by ID.
    func scrollTo(id: ID, anchor: UnitPoint, animated: Bool)

    /// Call before inserting items at the front of the data.
    /// Semantics differ per backend (SwiftUI captures anchor snapshot,
    /// UIKit uses batch update offset correction).
    func prepareToPrepend()
}

/// Optional diagnostics — backends provide these for debug HUD / example app.
/// Not required for basic consumer usage.
public protocol ChatViewportDiagnostics {
    associatedtype ID: Hashable

    /// The ID of the topmost visible item.
    var topVisibleItemID: ID? { get }

    /// Distance from the bottom of the scroll content.
    /// nil when the scroll view bridge is not established (SwiftUI) or view not loaded (UIKit).
    var distanceFromBottom: CGFloat? { get }
}
