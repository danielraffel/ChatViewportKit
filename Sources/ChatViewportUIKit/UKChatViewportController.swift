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
    public internal(set) weak var collectionView: UICollectionView?

    /// Reference to the data source for indexPath lookups.
    /// Stored here since cv.dataSource is the DiffableDataSource wrapper.
    internal var dataSourceRef: UKDataSourceBase<ID>?

    /// The ID of the topmost visible item.
    public internal(set) var topVisibleItemID: ID?

    /// Distance from the bottom of the scroll content.
    public var distanceFromBottom: CGFloat? {
        guard let cv = collectionView else { return nil }
        let maxOffset = cv.contentSize.height - cv.bounds.height + cv.adjustedContentInset.bottom
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

    /// Guards against mode transitions during programmatic scrolling.
    internal var programmaticScrollInFlight: Bool = false

    /// When true, an auto-scroll to bottom is in flight. Subsequent appends
    /// during a burst should continue to auto-scroll even if mode briefly
    /// transitions away from pinned. Mirrors SwiftUI backend's autoScrollPending.
    internal var autoScrollPending: Bool = false

    public init() {}

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        guard let cv = collectionView else { return }
        let sections = cv.numberOfSections
        guard sections > 0 else { return }
        let items = cv.numberOfItems(inSection: sections - 1)
        guard items > 0 else { return }

        programmaticScrollInFlight = true
        cv.layoutIfNeeded()
        cv.scrollToItem(
            at: IndexPath(item: items - 1, section: sections - 1),
            at: .bottom,
            animated: animated
        )
        if !animated {
            programmaticScrollInFlight = false
        }
        transitionMode(.pinnedToBottom)
    }

    public func scrollToTop(animated: Bool = true) {
        guard let cv = collectionView else { return }
        let topOffset = -cv.adjustedContentInset.top
        programmaticScrollInFlight = true
        cv.setContentOffset(CGPoint(x: 0, y: topOffset), animated: animated)
        if !animated {
            programmaticScrollInFlight = false
        }
        transitionMode(.freeBrowsing(anchor: nil))
    }

    public func scrollTo(id: ID, anchor: UnitPoint = .center, animated: Bool = true) {
        guard let cv = collectionView,
              let dataSource = dataSourceRef,
              let indexPath = dataSource.indexPath(for: id) else { return }

        // Map UnitPoint to UICollectionView scroll position
        let position: UICollectionView.ScrollPosition
        if anchor == .top {
            position = .top
        } else if anchor == .bottom {
            position = .bottom
        } else {
            position = .centeredVertically
        }

        programmaticScrollInFlight = true
        cv.scrollToItem(at: indexPath, at: position, animated: animated)
        if !animated {
            programmaticScrollInFlight = false
        }
        transitionMode(.freeBrowsing(anchor: nil))
    }

    /// Overscroll past the top then snap back — forces navigation bar to
    /// re-render when switching between large and inline title display modes.
    public func bounceToTop(animated: Bool = true) {
        guard let cv = collectionView else { return }
        programmaticScrollInFlight = true
        let topOffset = -cv.adjustedContentInset.top
        cv.setContentOffset(CGPoint(x: 0, y: topOffset - 100), animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak cv] in
            guard let cv = cv else { return }
            let newTop = -cv.adjustedContentInset.top
            cv.setContentOffset(CGPoint(x: 0, y: newTop), animated: animated)
            self?.programmaticScrollInFlight = false
        }
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
        // Don't transition during programmatic scrolls
        guard !programmaticScrollInFlight else { return }
        guard let cv = collectionView else { return }

        let contentHeight = cv.contentSize.height
        let viewportHeight = cv.bounds.height
        let maxOffset = contentHeight - viewportHeight + cv.adjustedContentInset.bottom
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
