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

    /// Height index for probe-align scrollTo(id:) engine.
    /// Plain property, NOT @Published — avoids unnecessary view invalidation (design rule 3).
    internal let heightIndex = HeightIndex<ID>()

    // MARK: - Probe-align session state (plain properties, NOT @Published — design rule 3)

    /// When true, a probe-align scrollTo(id:) session is in flight.
    /// Guards updateBottomPinState from transitioning mode during probing (design rule 4).
    internal var idScrollInFlight: Bool = false

    /// The snapshot overlay covering the viewport during probe jumps.
    /// Attached to scroll view's SUPERVIEW, not inside scroll content (design rule 2).
    private weak var probeOverlay: UIView?

    /// Generation counter for cancelling stale probe sessions.
    private var probeSessionGeneration: UInt64 = 0

    /// Ordered IDs cache — rebuilt lazily at scrollTo call time (design rule 5).
    internal var orderedIDs: [ID] = []

    /// Configuration spacing — set by ChatViewport during body evaluation.
    internal var configSpacing: CGFloat = 8

    /// Whether the UIScrollView bridge has been established (for debugging).
    public var hasScrollViewRef: Bool { scrollViewRef != nil }

    /// Whether the anchor is currently frozen (for debugging).
    public var freezeAnchorState: Bool { freezeAnchor }

    /// Number of measured heights in the index (for debugging).
    public var heightIndexCount: Int { heightIndex.heights.count }

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
        // If no bridge, fall back to ScrollViewProxy (works for nearby items).
        guard let scrollView = scrollViewRef else {
            // print("[PROBE] scrollTo: no bridge, falling back to proxy")
            issueCommand(.scrollTo(id: id, anchor: anchor, animated: animated))
            transitionMode(.freeBrowsing(anchor: nil))
            return
        }

        // Check if target is already measured and nearby — skip probing
        if heightIndex.heights[id] != nil {
            // print("[PROBE] scrollTo: target already measured, using proxy")
            // Target has been materialized before. Try direct proxy scroll first.
            // For nearby items this is sufficient and avoids overlay flash.
            issueCommand(.scrollTo(id: id, anchor: anchor, animated: animated))
            transitionMode(.freeBrowsing(anchor: nil))
            return
        }

        // print("[PROBE] scrollTo: target NOT measured, starting probe-align. Heights: \(heightIndex.heights.count), orderedIDs: \(orderedIDs.count)")
        // Far target — use probe-align engine
        startProbeAlign(targetID: id, anchor: anchor, animated: animated, scrollView: scrollView)
    }

    // MARK: - Probe-Align Engine

    /// Cancel any in-flight probe session. Called on data count change, height mutations,
    /// Dynamic Type changes, or any layout-affecting change (design rule 4a).
    internal func cancelProbeSession() {
        guard idScrollInFlight else { return }
        // print("[PROBE] CANCELLED — session aborted")
        probeSessionGeneration &+= 1
        cleanupProbeSession()
    }

    private func cleanupProbeSession() {
        idScrollInFlight = false
        probeOverlay?.removeFromSuperview()
        probeOverlay = nil
    }

    /// Start a probe-align session to scroll to a far (unmaterialized) target.
    private func startProbeAlign(targetID: ID, anchor: UnitPoint, animated: Bool, scrollView: UIScrollView) {
        // Cancel any existing session
        cancelProbeSession()

        idScrollInFlight = true
        let sessionGen = probeSessionGeneration
        transitionMode(.programmaticScroll(target: .id(targetID, anchor: anchor)))

        // Step 1: Capture snapshot overlay on scroll view's SUPERVIEW (design rule 2).
        // This masks the wrong-content flash during probing.
        if let superview = scrollView.superview {
            let snapshot = scrollView.snapshotView(afterScreenUpdates: false) ?? UIView()
            snapshot.frame = scrollView.frame
            superview.addSubview(snapshot)
            probeOverlay = snapshot
            // print("[PROBE] Overlay attached to superview")
        } else {
            // print("[PROBE] WARNING: no superview for overlay")
        }

        // Step 2: Compute estimated offset.
        // Use proportional estimate from contentSize when few heights are measured,
        // since small samples from the bottom can have unrepresentative averages.
        let estimatedOffset: CGFloat
        let targetIdx = orderedIDs.firstIndex(of: targetID)
        let contentSize = scrollView.contentSize.height

        if heightIndex.heights.count > 100, let _ = targetIdx {
            estimatedOffset = heightIndex.estimatedOffset(
                to: targetID, in: orderedIDs, spacing: configSpacing
            )
        } else if let idx = targetIdx {
            // Proportional estimate — contentSize includes all variable heights
            estimatedOffset = contentSize * (CGFloat(idx) / CGFloat(orderedIDs.count))
        } else {
            estimatedOffset = heightIndex.estimatedOffset(
                to: targetID, in: orderedIDs, spacing: configSpacing
            )
        }

        // print("[PROBE] estimatedOffset=\(Int(estimatedOffset)), measured=\(heightIndex.heights.count), contentSize=\(Int(contentSize))")

        // Step 3: Jump to estimated position (snap, not animated)
        let topInset = scrollView.adjustedContentInset.top
        // print("[PROBE] Jumping to y=\(estimatedOffset - topInset), topInset=\(topInset)")
        scrollView.setContentOffset(CGPoint(x: 0, y: estimatedOffset - topInset), animated: false)

        // Step 4: Wait for layout to settle, then refine (two async hops — design rule 7).
        // GCD is correct here — UIKit layoutIfNeeded needs synchronous main thread,
        // not Swift concurrency Task.
        probePass(
            targetID: targetID,
            anchor: anchor,
            animated: animated,
            scrollView: scrollView,
            sessionGen: sessionGen,
            passNumber: 1,
            maxPasses: 3
        )
    }

    private func probePass(
        targetID: ID,
        anchor: UnitPoint,
        animated: Bool,
        scrollView: UIScrollView,
        sessionGen: UInt64,
        passNumber: Int,
        maxPasses: Int
    ) {
        // print("[PROBE] probePass \(passNumber)/\(maxPasses)")
        // First async hop: let SwiftUI materialize views at new offset
        DispatchQueue.main.async { [weak self, weak scrollView] in
            guard let self = self, let scrollView = scrollView else { return }
            guard self.probeSessionGeneration == sessionGen, self.idScrollInFlight else { return }

            // Flush UIKit layout
            scrollView.layoutIfNeeded()

            // Second async hop: wait for SwiftUI to materialize lazy content and propagate preferences.
            // 250ms gives time for large datasets with variable heights. Two hops total (design rule 7).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak scrollView] in
                guard let self = self, let scrollView = scrollView else { return }
                guard self.probeSessionGeneration == sessionGen, self.idScrollInFlight else { return }

                scrollView.layoutIfNeeded()
                // print("[PROBE] probePass \(passNumber): heights=\(self.heightIndex.heights.count)")

                // Check if target is now measured
                if let measuredHeight = self.heightIndex.heights[targetID] {
                    // print("[PROBE] TARGET FOUND! measuredHeight=\(measuredHeight)")
                    self.finishProbeWithTarget(
                        targetID: targetID, measuredHeight: measuredHeight,
                        anchor: anchor, animated: animated, scrollView: scrollView
                    )
                } else if passNumber < maxPasses {
                    // Correct offset using topVisibleItemID if available
                    self.correctAndRetry(
                        targetID: targetID, anchor: anchor, animated: animated,
                        scrollView: scrollView, sessionGen: sessionGen,
                        passNumber: passNumber, maxPasses: maxPasses
                    )
                } else {
                    // print("[PROBE] MAX PASSES EXHAUSTED, falling back to proxy")
                    self.finishProbeSession(animated: false)
                    self.transitionMode(.freeBrowsing(anchor: nil))
                    self.issueCommand(.scrollTo(id: targetID, anchor: anchor, animated: false))
                    // Silent verification — we're now close, retry will be precise
                    self.scheduleVerification(targetID: targetID, anchor: anchor, scrollView: scrollView)
                }
            }
        }
    }

    /// Called when probe finds the target — compute precise offset and snap to it.
    private func finishProbeWithTarget(
        targetID: ID, measuredHeight: CGFloat,
        anchor: UnitPoint, animated: Bool, scrollView: UIScrollView
    ) {
        let preciseOffset = heightIndex.estimatedOffset(
            to: targetID, in: orderedIDs, spacing: configSpacing
        )
        let topInset = scrollView.adjustedContentInset.top
        var targetY = preciseOffset - topInset

        // Adjust for anchor position (design rule 9)
        if anchor == .center {
            let viewportHeight = scrollView.bounds.height
            targetY = preciseOffset - topInset - (viewportHeight - measuredHeight) / 2
        } else if anchor == .bottom {
            let viewportHeight = scrollView.bounds.height
            targetY = preciseOffset - topInset - viewportHeight + measuredHeight
        }

        // Clamp to valid range
        let maxOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
        targetY = min(max(targetY, -topInset), maxOffset)

        let residual = abs(targetY - scrollView.contentOffset.y)
        let shouldAnimate = animated && residual < 100
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        scrollView.setContentOffset(
            CGPoint(x: 0, y: targetY),
            animated: shouldAnimate && !reduceMotion
        )

        finishProbeSession(animated: shouldAnimate && !reduceMotion)
        transitionMode(.freeBrowsing(anchor: nil))
        UIAccessibility.post(notification: .layoutChanged, argument: nil)

        // Silent verification: after layout settles, check if we actually
        // landed on the target. If not, the target is now nearby and measured,
        // so a second scrollTo will be precise.
        scheduleVerification(targetID: targetID, anchor: anchor, scrollView: scrollView)
    }

    /// Called when probe doesn't find the target — correct offset and schedule next pass.
    private func correctAndRetry(
        targetID: ID, anchor: UnitPoint, animated: Bool,
        scrollView: UIScrollView, sessionGen: UInt64,
        passNumber: Int, maxPasses: Int
    ) {
        let topInset = scrollView.adjustedContentInset.top
        let currentOffset = scrollView.contentOffset.y
        let targetIdx = orderedIDs.firstIndex(of: targetID)

        if let visibleID = topVisibleItemID,
           let visibleIdx = orderedIDs.firstIndex(of: visibleID),
           let targIdx = targetIdx {
            // Use proportional per-item offset from contentSize (more accurate than
            // avgHeight when samples are few or heights vary significantly).
            let delta = targIdx - visibleIdx
            let contentSize = scrollView.contentSize.height
            let perItem = contentSize / CGFloat(orderedIDs.count)
            let jump = CGFloat(delta) * perItem
            let correctedOffset = currentOffset + jump
            // print("[PROBE] pass \(passNumber): visible=\(visibleIdx), target=\(targIdx), delta=\(delta), perItem=\(String(format: "%.1f", perItem))")
            scrollView.setContentOffset(CGPoint(x: 0, y: correctedOffset), animated: false)
        } else if let targIdx = targetIdx {
            // No visible anchor. Use proportional estimate from content size
            // (more reliable than heightIndex average with few samples).
            let contentSize = scrollView.contentSize.height
            let total = CGFloat(orderedIDs.count)
            let proportionalOffset = contentSize * (CGFloat(targIdx) / total)
            // print("[PROBE] pass \(passNumber): proportional re-estimate to \(Int(proportionalOffset))")
            scrollView.setContentOffset(CGPoint(x: 0, y: proportionalOffset - topInset), animated: false)
        } else {
            let reEstimate = heightIndex.estimatedOffset(
                to: targetID, in: orderedIDs, spacing: configSpacing
            )
            // print("[PROBE] pass \(passNumber): fallback re-estimate to \(Int(reEstimate))")
            scrollView.setContentOffset(CGPoint(x: 0, y: reEstimate - topInset), animated: false)
        }

        // Wait for SwiftUI to materialize content at corrected offset before next pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak scrollView] in
            guard let self = self, let scrollView = scrollView else { return }
            guard self.probeSessionGeneration == sessionGen, self.idScrollInFlight else { return }
            self.probePass(
                targetID: targetID, anchor: anchor, animated: animated,
                scrollView: scrollView, sessionGen: sessionGen,
                passNumber: passNumber + 1, maxPasses: maxPasses
            )
        }
    }

    /// After a probe session completes, verify we actually landed near the target.
    /// If not, the target should now be measured (we got close), so a second
    /// scrollTo will use the fast path with precise height data.
    private func scheduleVerification(targetID: ID, anchor: UnitPoint, scrollView: UIScrollView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak scrollView] in
            guard let self = self, let scrollView = scrollView else { return }
            // Don't interfere if user has started scrolling or another command is in flight
            guard !self.idScrollInFlight else { return }

            // Check if target is visible by looking at visible content
            scrollView.layoutIfNeeded()
            let targetMeasured = self.heightIndex.heights[targetID] != nil

            if targetMeasured {
                // Target was materialized during probing — we have precise height data.
                // Recompute precise offset and correct silently if needed.
                let preciseOffset = self.heightIndex.estimatedOffset(
                    to: targetID, in: self.orderedIDs, spacing: self.configSpacing
                )
                let topInset = scrollView.adjustedContentInset.top
                var targetY = preciseOffset - topInset

                if anchor == .center {
                    let viewportHeight = scrollView.bounds.height
                    let h = self.heightIndex.heights[targetID] ?? 44
                    targetY = preciseOffset - topInset - (viewportHeight - h) / 2
                } else if anchor == .bottom {
                    let viewportHeight = scrollView.bounds.height
                    let h = self.heightIndex.heights[targetID] ?? 44
                    targetY = preciseOffset - topInset - viewportHeight + h
                }

                let maxOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
                targetY = min(max(targetY, -topInset), maxOffset)

                let drift = abs(targetY - scrollView.contentOffset.y)
                if drift > 100 {
                    // Significant drift — correct silently
                    let reduceMotion = UIAccessibility.isReduceMotionEnabled
                    scrollView.setContentOffset(
                        CGPoint(x: 0, y: targetY),
                        animated: !reduceMotion
                    )
                }
            } else {
                // Target still not measured — try scrollTo again.
                // Being closer now means the probe will converge faster.
                self.scrollTo(id: targetID, anchor: anchor, animated: true)
            }
        }
    }

    private func finishProbeSession(animated: Bool) {
        if animated {
            // Fade out overlay for smooth transition
            UIView.animate(withDuration: 0.15) { [weak self] in
                self?.probeOverlay?.alpha = 0
            } completion: { [weak self] _ in
                self?.cleanupProbeSession()
            }
        } else {
            cleanupProbeSession()
        }
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
