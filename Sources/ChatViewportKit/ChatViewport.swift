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
    @State private var scrollProxy: ScrollViewProxy?

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
                        let items = Array(data)
                        ForEach(items.indices, id: \.self) { index in
                            let item = items[index]
                            let itemID = item[keyPath: idKeyPath]
                            rowContent(item)
                                .id(itemID)
                        }
                    }
                    .frame(minHeight: outerProxy.size.height, alignment: .bottom)
                }
                .onAppear {
                    scrollProxy = proxy
                    viewportHeight = outerProxy.size.height
                    updateControllerIDs()
                }
                .onChange(of: outerProxy.size.height) { newHeight in
                    viewportHeight = newHeight
                }
                .onChange(of: data.count) { _ in
                    updateControllerIDs()
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
