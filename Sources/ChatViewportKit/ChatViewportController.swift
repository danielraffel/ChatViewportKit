import SwiftUI
import UIKit

/// Controller for imperative scroll commands and viewport state on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject {

    // MARK: - Published state

    /// The current viewport mode — drives behavior on data changes and scroll events.
    public private(set) var mode: ViewportMode<ID> = .initialBottomAnchored

    /// Whether the viewport is currently pinned to the bottom (derived from mode).
    public var isPinnedToBottom: Bool {
        switch mode {
        case .initialBottomAnchored, .pinnedToBottom: return true
        case .freeBrowsing, .programmaticScroll, .correctingAfterDataChange: return false
        }
    }

    // MARK: - Command dispatch (non-published; generation counter triggers view)

    /// The current scroll command to execute (consumed by ChatViewport).
    internal var pendingCommand: ScrollCommand<ID>?

    /// Generation counter — the view observes this to detect new commands.
    /// Using a counter avoids the double-publish of set-then-nil on pendingCommand.
    @Published internal var commandGeneration: UInt64 = 0

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
        pendingCommand = command
        commandGeneration &+= 1
    }

    // MARK: - Mode transitions (called by ChatViewport internals)

    internal func transitionMode(_ newMode: ViewportMode<ID>) {
        guard mode != newMode else { return }
        let wasPinned = isPinnedToBottom
        objectWillChange.send()
        mode = newMode
        let nowPinned = isPinnedToBottom
        if nowPinned != wasPinned {
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
