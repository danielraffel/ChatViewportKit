import SwiftUI
import UIKit
import ChatViewportCore

/// A bottom-anchored viewport for displaying scrollable content with chat-like behavior,
/// backed by UICollectionView.
///
/// This is the UIKit backend alternative to `ChatViewport` (LazyVStack backend).
/// It provides the same API surface but uses UICollectionView for scrolling,
/// which gives native `scrollToItem` and deterministic layout control.
public struct UKChatViewport<Data, ID, RowContent>: UIViewRepresentable
where Data: RandomAccessCollection, ID: Hashable, RowContent: View {

    private let data: Data
    private let idKeyPath: KeyPath<Data.Element, ID>
    private let rowContent: (Data.Element) -> RowContent

    @ObservedObject private var controller: UKChatViewportController<ID>
    private let configuration: ChatViewportConfiguration

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        controller: UKChatViewportController<ID>,
        configuration: ChatViewportConfiguration = .init(),
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.idKeyPath = id
        self.controller = controller
        self.configuration = configuration
        self.rowContent = rowContent
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, configuration: configuration)
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let layout = UKBottomAnchoredLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = configuration.spacing
        layout.estimatedItemSize = CGSize(width: 100, height: 44) // Self-sizing placeholder

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = configuration.showsIndicators
        collectionView.keyboardDismissMode = .interactive
        collectionView.delegate = context.coordinator

        // Wire up controller
        controller.collectionView = collectionView
        controller.configuration = configuration

        // Create data source
        let dataSource = UKDataSource<Data, ID, RowContent>(
            collectionView: collectionView,
            idKeyPath: idKeyPath,
            rowContent: rowContent
        )
        context.coordinator.dataSource = dataSource

        // Apply initial data
        dataSource.apply(data: data, animated: false)

        return collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        guard let dataSource = context.coordinator.dataSource else { return }

        let previousCount = context.coordinator.previousItemCount
        let newCount = data.count
        let wasPinned = controller.isPinnedToBottom
        let isPrepend = controller.prependInFlight && newCount > previousCount

        // Apply new data
        dataSource.apply(data: data, animated: false)
        context.coordinator.previousItemCount = newCount

        // Handle prepend offset correction
        if isPrepend {
            let oldContentSize = controller.prePrependContentSize
            collectionView.layoutIfNeeded()
            let newContentSize = collectionView.contentSize.height
            let delta = newContentSize - oldContentSize
            if delta > 0 {
                let currentOffset = collectionView.contentOffset.y
                collectionView.setContentOffset(
                    CGPoint(x: 0, y: currentOffset + delta),
                    animated: false
                )
            }
            controller.prependInFlight = false
        }

        // Auto-scroll on append when pinned
        if !isPrepend && newCount > previousCount && wasPinned {
            DispatchQueue.main.async {
                controller.scrollToBottom(animated: true)
            }
        }
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        let controller: UKChatViewportController<ID>
        let configuration: ChatViewportConfiguration
        var dataSource: UKDataSource<Data, ID, RowContent>?
        var previousItemCount: Int = 0

        init(controller: UKChatViewportController<ID>, configuration: ChatViewportConfiguration) {
            self.controller = controller
            self.configuration = configuration
        }

        // Self-sizing is handled by UIHostingConfiguration + estimatedItemSize.
        // Do NOT implement sizeForItemAt — it disables self-sizing.

        // MARK: - UIScrollViewDelegate

        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            controller.updateBottomPinState()

            // Update topVisibleItemID
            if let cv = scrollView as? UICollectionView,
               let topPath = cv.indexPathsForVisibleItems.sorted().first,
               let dataSource = dataSource {
                controller.topVisibleItemID = dataSource.id(at: topPath)
            }
        }
    }
}

// MARK: - Convenience for Identifiable data
extension UKChatViewport where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data,
        controller: UKChatViewportController<ID>,
        configuration: ChatViewportConfiguration = .init(),
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.init(data, id: \.id, controller: controller, configuration: configuration, rowContent: rowContent)
    }
}
