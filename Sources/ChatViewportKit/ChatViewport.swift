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
            let _ = outerProxy // suppress unused warning; will be used for viewport measurement
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: configuration.spacing) {
                        ForEach(dataElements, id: \.id) { element in
                            rowContent(element.item)
                                .id(element.id)
                        }
                    }
                }
                .onAppear {
                    controller.scrollProxy = scrollProxy
                }
            }
        }
    }

    /// Wraps data elements with extracted IDs for ForEach compatibility.
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
