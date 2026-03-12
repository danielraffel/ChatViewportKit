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
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: configuration.showsIndicators) {
                    LazyVStack(spacing: configuration.spacing) {
                        ForEach(dataElements, id: \.id) { element in
                            rowContent(element.item)
                                .id(element.id)
                        }
                    }
                    .frame(minHeight: outerProxy.size.height, alignment: .bottom)
                }
                .onAppear {
                    controller.scrollProxy = scrollProxy
                    viewportHeight = outerProxy.size.height
                    updateControllerIDs()
                }
                .onChange(of: outerProxy.size.height) { newHeight in
                    viewportHeight = newHeight
                }
                .onChange(of: data.count) { _ in
                    updateControllerIDs()
                }
            }
        }
    }

    // MARK: - Internal helpers

    private func updateControllerIDs() {
        controller.firstItemID = data.first?[keyPath: idKeyPath]
        controller.lastItemID = data.last?[keyPath: idKeyPath]
    }

    // MARK: - Data mapping

    private var dataElements: [IdentifiedElement] {
        data.map { IdentifiedElement(id: $0[keyPath: idKeyPath], item: $0) }
    }

    private struct IdentifiedElement: Identifiable {
        let id: ID
        let item: Data.Element
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
