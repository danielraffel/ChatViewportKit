import SwiftUI
import UIKit
import ChatViewportCore

/// Controller for imperative scroll commands and viewport state on a UICollectionView-backed chat viewport.
///
/// Conforms to `ChatViewportControllerProtocol` and `ChatViewportDiagnostics` so consumers
/// can use either backend through the shared protocol surface.
public final class UKChatViewportController<ID: Hashable>: ObservableObject, ChatViewportControllerProtocol, ChatViewportDiagnostics {

    // MARK: - Published state

    /// The current viewport mode — drives behavior on data changes and scroll events.
    @Published public private(set) var mode: ViewportMode<ID> = .initialBottomAnchored

    /// Whether the viewport is currently pinned to the bottom (derived from mode).
    public var isPinnedToBottom: Bool {
        switch mode {
        case .initialBottomAnchored, .pinnedToBottom: return true
        case .freeBrowsing, .programmaticScroll, .correctingAfterDataChange: return false
        }
    }

    /// Callback when pinned-to-bottom state changes (for host "jump to latest" UI).
    public var onBottomPinnedChanged: ((Bool) -> Void)?

    // MARK: - Internal state

    /// Reference to the UICollectionView — set by UKChatViewport during setup.
    internal weak var collectionView: UICollectionView?

    /// The ID of the topmost visible item.
    public internal(set) var topVisibleItemID: ID?

    /// Distance from the bottom of the scroll content.
    public var distanceFromBottom: CGFloat? {
        guard let cv = collectionView else { return nil }
        let maxOffset = cv.contentSize.height - cv.bounds.height + cv.contentInset.bottom
        return maxOffset - cv.contentOffset.y
    }

    /// Configuration — set during view setup.
    internal var configuration: ChatViewportConfiguration = .init()

    /// Captures pinned state before data count changes (mirrors SwiftUI backend).
    internal var wasPinnedBeforeCountChange: Bool = false

    /// Whether a prepend operation is in flight.
    internal var prependInFlight: Bool = false

    /// Content size before a prepend, for offset correction.
    internal var prePrependContentSize: CGFloat = 0

    public init() {}

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        guard let cv = collectionView else { return }
        let maxOffset = cv.contentSize.height - cv.bounds.height + cv.contentInset.bottom
        if maxOffset > 0 {
            cv.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: animated)
        }
        transitionMode(.pinnedToBottom)
    }

    public func scrollToTop(animated: Bool = true) {
        guard let cv = collectionView else { return }
        let topOffset = -cv.adjustedContentInset.top
        cv.setContentOffset(CGPoint(x: 0, y: topOffset), animated: animated)
        transitionMode(.freeBrowsing(anchor: nil))
    }

    public func scrollTo(id: ID, anchor: UnitPoint = .center, animated: Bool = true) {
        guard let cv = collectionView,
              let dataSource = cv.dataSource as? UKDataSourceBase<ID> else { return }

        guard let indexPath = dataSource.indexPath(for: id) else { return }

        // Map UnitPoint to UICollectionView scroll position
        let position: UICollectionView.ScrollPosition
        if anchor == .top {
            position = .top
        } else if anchor == .bottom {
            position = .bottom
        } else {
            position = .centeredVertically
        }

        cv.scrollToItem(at: indexPath, at: position, animated: animated)
        transitionMode(.freeBrowsing(anchor: nil))
    }

    public func prepareToPrepend() {
        guard let cv = collectionView else { return }
        prependInFlight = true
        prePrependContentSize = cv.contentSize.height
    }

    // MARK: - Mode transitions

    internal func transitionMode(_ newMode: ViewportMode<ID>) {
        guard mode != newMode else { return }
        let wasPinned = isPinnedToBottom
        mode = newMode
        let nowPinned = isPinnedToBottom
        if nowPinned != wasPinned {
            onBottomPinnedChanged?(nowPinned)
        }
    }

    // MARK: - Bottom-pin detection (called from scroll delegate)

    internal func updateBottomPinState() {
        guard let cv = collectionView else { return }

        let contentHeight = cv.contentSize.height
        let viewportHeight = cv.bounds.height
        let maxOffset = contentHeight - viewportHeight + cv.contentInset.bottom
        let actualDistance = maxOffset - cv.contentOffset.y

        let isUnderfilled = contentHeight <= viewportHeight
        let isAtBottom = actualDistance <= configuration.bottomPinThreshold

        if isUnderfilled || isAtBottom {
            if !isPinnedToBottom {
                transitionMode(.pinnedToBottom)
            }
        } else {
            if isPinnedToBottom {
                transitionMode(.freeBrowsing(anchor: nil))
            }
        }
    }
}

/// Type-erased base for the data source to allow controller to query it.
internal class UKDataSourceBase<ID: Hashable>: NSObject {
    func indexPath(for id: ID) -> IndexPath? { nil }
}
