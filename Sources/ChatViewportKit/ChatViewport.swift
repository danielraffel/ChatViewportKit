import SwiftUI

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
                                        Color.clear.preference(
                                            key: RowFramesPreference<ID>.self,
                                            value: [RowFrame(
                                                id: itemID,
                                                minY: rowProxy.frame(in: .named(viewportCoordinateSpace)).minY,
                                                maxY: rowProxy.frame(in: .named(viewportCoordinateSpace)).maxY
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
                    let sorted = frames.sorted { $0.minY < $1.minY }
                    controller.topVisibleItemID = sorted.first(where: { $0.maxY > 0 })?.id
                }
                .onAppear {
                    scrollProxy = proxy
                    viewportHeight = outerProxy.size.height
                    previousCount = data.count
                    updateControllerIDs()
                }
                .onChange(of: outerProxy.size.height) { newHeight in
                    viewportHeight = newHeight
                }
                .onChange(of: data.count) { newCount in
                    let currentLastID = data.last?[keyPath: idKeyPath]
                    updateControllerIDs()

                    // Use freezeAnchor flag (set by prepareToPrepend) as the prepend signal.
                    // This is more reliable than ID-change detection because SwiftUI's
                    // onChange closure may capture stale data references.
                    let isPrepend = controller.freezeAnchor && newCount > previousCount
                    let isAppend = !isPrepend && newCount > previousCount

                    if isPrepend {
                        if let scrollView = controller.scrollViewRef {
                            let capturedOffsetY = scrollView.contentOffset.y
                            let capturedContentSize = scrollView.contentSize.height

                            // Defer offset adjustment until after SwiftUI completes layout.
                            // Using async (next run loop) is enough for SwiftUI to update contentSize.
                            DispatchQueue.main.async {
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
                    } else if isAppend && controller.isPinnedToBottom, let lastID = currentLastID {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }

                    previousCount = newCount
                }
                .onChange(of: controller.pendingCommand) { command in
                    guard let command = command else { return }
                    executeCommand(command, proxy: proxy)
                    DispatchQueue.main.async {
                        controller.pendingCommand = nil
                    }
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
        }
    }

    private func updateControllerIDs() {
        controller.firstItemID = data.first?[keyPath: idKeyPath]
        controller.lastItemID = data.last?[keyPath: idKeyPath]
    }

    private func updateBottomPinState(scrollOffset: CGFloat) {
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
