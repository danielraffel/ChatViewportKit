import SwiftUI
import ChatViewportCore

/// A bottom-anchored viewport for displaying scrollable content with chat-like behavior.
///
/// Content is rendered in a `LazyVStack` inside a real `ScrollView`. When content is shorter
/// than the viewport, it is pushed to the bottom via a layout-based filler — no scroll-on-appear hack.
public struct ChatViewport<Data, ID, RowContent>: View
where Data: RandomAccessCollection, ID: Hashable, RowContent: View {

    private let data: Data
    private let idKeyPath: KeyPath<Data.Element, ID>
    private let rowContent: (Data.Element) -> RowContent

    @ObservedObject private var controller: ChatViewportController<ID>
    private let configuration: ChatViewportConfiguration

    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var previousCount: Int = 0
    @State private var previousContentHeight: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        controller: ChatViewportController<ID>,
        configuration: ChatViewportConfiguration = .init(),
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.idKeyPath = id
        self.controller = controller
        self.configuration = configuration
        self.rowContent = rowContent
    }

    public var body: some View {
        // Update controller IDs during body evaluation where data is always fresh.
        // onChange closures capture stale data references, so we cannot read data there.
        // Also capture pinned state BEFORE preferences fire — large appends cause
        // ScrollOffsetPreference to transition mode to freeBrowsing before onChange runs.
        let _ = {
            let newFirst = data.first?[keyPath: idKeyPath]
            let newLast = data.last?[keyPath: idKeyPath]

            // Detect full data replacement (both first and last IDs changed).
            // Invalidate height index so stale entries don't corrupt averageHeight.
            let firstChanged = newFirst != controller.firstItemID
            let lastChanged = newLast != controller.lastItemID
            if firstChanged && lastChanged && controller.firstItemID != nil {
                controller.heightIndex.invalidateAll()
            }

            controller.firstItemID = newFirst
            controller.lastItemID = newLast
            // Update ordered IDs for probe-align (design rule 5: lazy, only rebuilt here).
            // Read from data during body evaluation where it's always fresh.
            controller.orderedIDs = data.map { $0[keyPath: idKeyPath] }
            controller.configSpacing = configuration.spacing
            if data.count != previousCount {
                // If an auto-scroll is already in flight (burst append), preserve intent.
                // Otherwise capture the actual pinned state before preferences fire.
                controller.wasPinnedBeforeCountChange = controller.isPinnedToBottom || controller.autoScrollPending
            }
        }()

        GeometryReader { outerProxy in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: configuration.showsIndicators) {
                    LazyVStack(spacing: configuration.spacing) {
                        ForEach(Array(data), id: idKeyPath) { item in
                            let itemID = item[keyPath: idKeyPath]
                            rowContent(item)
                                .id(itemID)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .background(
                                    GeometryReader { rowProxy in
                                        let frame = rowProxy.frame(in: .named(viewportCoordinateSpace))
                                        // Record height in index — reuses existing GeometryReader (design rule 6).
                                        // Simple dictionary write, no @Published, no view invalidation.
                                        let _ = controller.heightIndex.record(id: itemID, height: frame.height)
                                        Color.clear.preference(
                                            key: RowFramesPreference<ID>.self,
                                            value: [RowFrame(
                                                id: itemID,
                                                minY: frame.minY,
                                                maxY: frame.maxY
                                            )]
                                        )
                                    }
                                )
                        }
                    }
                    .frame(minHeight: outerProxy.size.height, alignment: .bottom)
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear
                                .preference(
                                    key: ContentHeightPreference.self,
                                    value: contentProxy.size.height
                                )
                                .preference(
                                    key: ScrollOffsetPreference.self,
                                    value: contentProxy.frame(in: .named(viewportCoordinateSpace)).minY
                                )
                        }
                    )
                    .background(
                        ScrollViewBridge { scrollView in
                            controller.scrollViewRef = scrollView
                        }
                    )
                }
                .coordinateSpace(name: viewportCoordinateSpace)
                .onPreferenceChange(ContentHeightPreference.self) { height in
                    previousContentHeight = contentHeight
                    contentHeight = height
                }
                .onPreferenceChange(ScrollOffsetPreference.self) { offset in
                    updateBottomPinState(scrollOffset: offset)
                }
                .onPreferenceChange(RowFramesPreference<ID>.self) { frames in
                    guard !controller.freezeAnchor else { return }
                    controller.topVisibleItemID = frames.first?.id
                }
                .onAppear {
                    scrollProxy = proxy
                    viewportHeight = outerProxy.size.height
                    viewportWidth = outerProxy.size.width
                    previousCount = data.count
                }
                .onChange(of: outerProxy.size.height) { newHeight in
                    let heightChanged = newHeight != viewportHeight
                    viewportHeight = newHeight
                    // When viewport resizes (keyboard show/hide) while pinned,
                    // auto-scroll to keep the bottom content in view.
                    if heightChanged && controller.isPinnedToBottom {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            controller.scrollToBottom(animated: false)
                        }
                    }
                }
                .onChange(of: outerProxy.size.width) { newWidth in
                    if newWidth != viewportWidth {
                        viewportWidth = newWidth
                        // Width change invalidates all cached heights — row content
                        // will re-layout at new width with different heights.
                        controller.heightIndex.invalidateAll()
                        // Cancel in-flight probe sessions (design rule 4a).
                        controller.cancelProbeSession()
                    }
                }
                .onChange(of: data.count) { newCount in
                    // NOTE: do NOT read `data` here — it may be stale.
                    // Use controller.firstItemID / controller.lastItemID which were
                    // updated during body evaluation with fresh data.

                    // Cancel in-flight probe sessions on data change (design rule 4a).
                    controller.cancelProbeSession()

                    let isPrepend = controller.freezeAnchor && newCount > previousCount
                    let isAppend = !isPrepend && newCount > previousCount

                    if isPrepend {
                        if let scrollView = controller.scrollViewRef {
                            let capturedOffsetY = scrollView.contentOffset.y
                            let capturedContentSize = scrollView.contentSize.height

                            // Defer offset adjustment until after SwiftUI completes layout.
                            // layoutIfNeeded() flushes pending UIKit layout before reading contentSize.
                            DispatchQueue.main.async {
                                scrollView.layoutIfNeeded()
                                let newSize = scrollView.contentSize.height
                                let delta = newSize - capturedContentSize
                                if delta > 0 {
                                    scrollView.setContentOffset(
                                        CGPoint(x: 0, y: capturedOffsetY + delta),
                                        animated: false
                                    )
                                } else {
                                    // Fallback: estimate from average row height
                                    let prependedCount = newCount - previousCount
                                    let avgHeight = capturedContentSize / CGFloat(max(previousCount, 1))
                                    let estimate = CGFloat(prependedCount) * avgHeight
                                    scrollView.setContentOffset(
                                        CGPoint(x: 0, y: capturedOffsetY + estimate),
                                        animated: false
                                    )
                                }
                                controller.freezeAnchor = false
                            }
                        } else if let anchorID = controller.topVisibleItemID {
                            // Fallback: scrollTo works for small prepends within render window
                            proxy.scrollTo(anchorID, anchor: .top)
                            controller.freezeAnchor = false
                        }
                    } else if isAppend && controller.wasPinnedBeforeCountChange {
                        // Auto-scroll to bottom after append when user was pinned.
                        // Mark intent so burst appends continue to auto-scroll even
                        // when mode briefly flips to freeBrowsing during layout.
                        controller.autoScrollPending = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            controller.scrollToBottomWithRetry {
                                controller.autoScrollPending = false
                            }
                        }
                        UIAccessibility.post(notification: .pageScrolled, argument: nil)
                    }

                    previousCount = newCount
                }
                .onChange(of: controller.commandGeneration) { _ in
                    guard let command = controller.pendingCommand else { return }
                    executeCommand(command, proxy: proxy)
                }
            }
        }
    }

    // MARK: - Internal helpers

    private func executeCommand(_ command: ScrollCommand<ID>, proxy: ScrollViewProxy) {
        switch command {
        case let .scrollTo(id, anchor, animated):
            if animated {
                withAnimation {
                    proxy.scrollTo(id, anchor: anchor)
                }
            } else {
                proxy.scrollTo(id, anchor: anchor)
            }
            // Notify VoiceOver that the layout changed due to programmatic scroll
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    private func updateBottomPinState(scrollOffset: CGFloat) {
        // Don't transition mode during probe-align session (design rule 4).
        // The probe engine owns mode transitions until it completes.
        guard !controller.idScrollInFlight else { return }

        let distanceFromBottom = contentHeight + scrollOffset - viewportHeight
        let isAtBottom = distanceFromBottom <= configuration.bottomPinThreshold
        let isUnderfilled = contentHeight <= viewportHeight

        if isUnderfilled || isAtBottom {
            if !controller.isPinnedToBottom {
                controller.transitionMode(.pinnedToBottom)
            }
        } else {
            if controller.isPinnedToBottom {
                controller.transitionMode(.freeBrowsing(anchor: nil))
            }
        }
    }
}

// MARK: - Convenience for Identifiable data
extension ChatViewport where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data,
        controller: ChatViewportController<ID>,
        configuration: ChatViewportConfiguration = .init(),
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.init(data, id: \.id, controller: controller, configuration: configuration, rowContent: rowContent)
    }
}
