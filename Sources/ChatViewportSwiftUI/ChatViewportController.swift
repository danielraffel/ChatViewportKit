import SwiftUI
import UIKit
import ChatViewportCore

/// Controller for imperative scroll commands and viewport state on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject, ChatViewportControllerProtocol, ChatViewportDiagnostics {

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

    /// Captures pinned state at body-evaluation time, before preference changes
    /// can transition the mode away from pinned during the same layout pass.
    public internal(set) var wasPinnedBeforeCountChange: Bool = false

    /// When true, an auto-scroll to bottom is in progress. Subsequent appends
    /// during a burst should continue to auto-scroll even if mode briefly
    /// transitions away from pinned during SwiftUI's layout pass.
    internal var autoScrollPending: Bool = false

    /// Weak reference to the hosting UIScrollView for direct contentOffset manipulation.
    /// Set by ScrollViewBridge; used for pixel-precise prepend offset correction.
    internal weak var scrollViewRef: UIScrollView?

    /// Whether the UIScrollView bridge has been established (for debugging).
    public var hasScrollViewRef: Bool { scrollViewRef != nil }

    /// Whether the anchor is currently frozen (for debugging).
    public var freezeAnchorState: Bool { freezeAnchor }

    /// Debug: distance from the bottom of the scroll view content.
    /// Returns nil if the scroll view bridge isn't established.
    public var distanceFromBottom: CGFloat? {
        guard let sv = scrollViewRef else { return nil }
        let maxOffset = sv.contentSize.height - sv.bounds.height + sv.contentInset.bottom
        return maxOffset - sv.contentOffset.y
    }

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
        // Use retry-based scroll so callers don't need to worry about timing
        // relative to SwiftUI's layout pass. The retry handles cases where
        // data was just appended and layout hasn't settled yet.
        scrollToBottomWithRetry(
            maxAttempts: 5,
            attemptInterval: 0.15,
            animated: animated
        )
    }

    /// Scroll to bottom with retry — ensures we reach the true bottom even when
    /// SwiftUI's layout is still settling (large batch appends, animations).
    internal func scrollToBottomWithRetry(maxAttempts: Int = 5, attemptInterval: TimeInterval = 0.15, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let scrollView = scrollViewRef else {
            // No bridge — fall back to single-shot proxy scroll
            if let id = lastItemID {
                issueCommand(.scrollTo(id: id, anchor: .bottom, animated: animated))
            }
            transitionMode(.pinnedToBottom)
            completion?()
            return
        }

        var attempt = 0
        func tryScroll() {
            guard attempt < maxAttempts else {
                completion?()
                return
            }
            attempt += 1
            DispatchQueue.main.async { [weak scrollView, weak self] in
                guard let scrollView = scrollView, let self = self else {
                    completion?()
                    return
                }
                scrollView.layoutIfNeeded()
                let bottomOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
                let currentOffset = scrollView.contentOffset.y
                let distanceFromBottom = bottomOffset - currentOffset

                if bottomOffset > 0 {
                    scrollView.setContentOffset(
                        CGPoint(x: 0, y: bottomOffset),
                        animated: animated && attempt == 1 // animate first attempt, snap subsequent
                    )
                }
                self.transitionMode(.pinnedToBottom)

                // If we're still far from bottom, layout may not be done — retry
                if distanceFromBottom > 50 && attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + attemptInterval) {
                        tryScroll()
                    }
                } else {
                    completion?()
                }
            }
        }
        tryScroll()
    }

    public func scrollToTop(animated: Bool = true) {
        // Use UIScrollView bridge with adjustedContentInset so we scroll
        // past the navigation bar to the true top. This also triggers
        // NavigationStack large title expansion.
        if let scrollView = scrollViewRef {
            DispatchQueue.main.async { [weak scrollView] in
                guard let scrollView = scrollView else { return }
                let topOffset = -scrollView.adjustedContentInset.top
                scrollView.setContentOffset(CGPoint(x: 0, y: topOffset), animated: animated)
            }
        } else if let id = firstItemID {
            issueCommand(.scrollTo(id: id, anchor: .top, animated: animated))
        }
        transitionMode(.freeBrowsing(anchor: nil))
    }

    /// Scroll to absolute top without animation.
    /// Accounts for navigation bar inset and forces large title expansion.
    public func scrollToAbsoluteTop() {
        if let scrollView = scrollViewRef {
            let topOffset = -scrollView.adjustedContentInset.top
            scrollView.setContentOffset(CGPoint(x: 0, y: topOffset), animated: false)
        } else if let id = firstItemID {
            issueCommand(.scrollTo(id: id, anchor: .top, animated: false))
        }
        transitionMode(.freeBrowsing(anchor: nil))
    }

    /// Scroll to top with a bounce that forces NavigationStack to re-render
    /// the title bar. Use after changing `navigationBarTitleDisplayMode`
    /// — SwiftUI doesn't always update the nav bar without a rubber-band trigger.
    public func bounceToTop() {
        guard let scrollView = scrollViewRef else {
            scrollToAbsoluteTop()
            return
        }
        // Step 1: overscroll past the top to trigger rubber-band
        let topOffset = -scrollView.adjustedContentInset.top
        scrollView.setContentOffset(CGPoint(x: 0, y: topOffset - 100), animated: false)
        // Step 2: after a beat, let it snap back to the natural resting position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak scrollView] in
            guard let scrollView = scrollView else { return }
            let newTop = -scrollView.adjustedContentInset.top
            scrollView.setContentOffset(CGPoint(x: 0, y: newTop), animated: true)
        }
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
