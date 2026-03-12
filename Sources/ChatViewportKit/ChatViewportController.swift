import SwiftUI
import UIKit

/// Controller for imperative scroll commands and viewport state on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject {

    // MARK: - Published state

    /// The current scroll command to execute (consumed by ChatViewport).
    @Published internal var pendingCommand: ScrollCommand<ID>?

    /// The current viewport mode — drives behavior on data changes and scroll events.
    @Published public private(set) var mode: ViewportMode<ID> = .initialBottomAnchored

    /// Whether the viewport is currently pinned to the bottom.
    @Published public private(set) var isPinnedToBottom: Bool = true

    // MARK: - Internal state (set by ChatViewport)

    internal var firstItemID: ID?
    internal var lastItemID: ID?

    /// The ID of the topmost visible item, continuously updated by preference key.
    /// Used for anchor restoration on prepend.
    public internal(set) var topVisibleItemID: ID?

    /// When true, the preference key update is skipped for one cycle.
    /// This preserves the pre-change anchor during a data mutation.
    internal var freezeAnchor: Bool = false

    /// Weak reference to the hosting UIScrollView for direct contentOffset manipulation.
    /// Set by ScrollViewBridge; used for pixel-precise prepend offset correction.
    internal weak var scrollViewRef: UIScrollView?

    /// Whether the UIScrollView bridge has been established (for debugging).
    public var hasScrollViewRef: Bool { scrollViewRef != nil }

    /// Whether the anchor is currently frozen (for debugging).
    public var freezeAnchorState: Bool { freezeAnchor }

    /// Generation counter to prevent stale commands from executing.
    /// Incremented each time a new command is issued; the view checks
    /// this before executing to skip superseded commands.
    internal var commandGeneration: UInt64 = 0

    /// Callback when pinned-to-bottom state changes (for host "jump to latest" UI).
    public var onBottomPinnedChanged: ((Bool) -> Void)?

    public init() {}

    /// Call before prepending data to freeze the current visible anchor.
    /// This ensures position restoration works correctly after prepend.
    public func prepareToPrepend() {
        freezeAnchor = true
    }

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        guard let id = lastItemID else { return }
        issueCommand(.scrollTo(id: id, anchor: .bottom, animated: animated))
        transitionMode(.pinnedToBottom)
    }

    public func scrollToTop(animated: Bool = true) {
        guard let id = firstItemID else { return }
        issueCommand(.scrollTo(id: id, anchor: .top, animated: animated))
        transitionMode(.freeBrowsing(anchor: nil))
    }

    public func scrollTo(id: ID, anchor: UnitPoint = .center, animated: Bool = true) {
        issueCommand(.scrollTo(id: id, anchor: anchor, animated: animated))
        transitionMode(.freeBrowsing(anchor: nil))
    }

    private func issueCommand(_ command: ScrollCommand<ID>) {
        commandGeneration &+= 1
        pendingCommand = command
    }

    // MARK: - Mode transitions (called by ChatViewport internals)

    internal func transitionMode(_ newMode: ViewportMode<ID>) {
        let wasPinned = isPinnedToBottom
        mode = newMode
        let nowPinned: Bool
        switch newMode {
        case .initialBottomAnchored, .pinnedToBottom:
            nowPinned = true
        case .freeBrowsing, .programmaticScroll, .correctingAfterDataChange:
            nowPinned = false
        }
        if nowPinned != wasPinned {
            isPinnedToBottom = nowPinned
            onBottomPinnedChanged?(nowPinned)
        }
    }
}

// MARK: - Scroll Command

internal enum ScrollCommand<ID: Hashable>: Equatable {
    case scrollTo(id: ID, anchor: UnitPoint, animated: Bool)

    static func == (lhs: ScrollCommand, rhs: ScrollCommand) -> Bool {
        switch (lhs, rhs) {
        case let (.scrollTo(lID, lAnchor, lAnimated), .scrollTo(rID, rAnchor, rAnimated)):
            return lID == rID && lAnchor == rAnchor && lAnimated == rAnimated
        }
    }
}
