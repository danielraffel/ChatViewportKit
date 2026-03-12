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
        controller.dataSourceRef = dataSource

        // Apply initial data
        dataSource.apply(data: data, animated: false)

        return collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        guard let dataSource = context.coordinator.dataSource else { return }

        let previousCount = context.coordinator.previousItemCount
        let newCount = data.count

        // Capture pinned state BEFORE applying data — matches SwiftUI backend's
        // body-evaluation prepass pattern. Include autoScrollPending for burst appends.
        let wasPinned = controller.isPinnedToBottom || controller.autoScrollPending
        let isPrepend = controller.prependInFlight && newCount > previousCount
        let isAppend = !isPrepend && newCount > previousCount

        // Capture current scroll position BEFORE data apply (for prepend correction).
        // Same pattern as SwiftUI backend: capture offsetY and contentSize before layout changes.
        let capturedOffsetY = collectionView.contentOffset.y
        let capturedContentSize = collectionView.contentSize.height

        // Apply new data
        dataSource.apply(data: data, animated: false)
        context.coordinator.previousItemCount = newCount

        // Handle prepend offset correction — preserve user's position.
        // Mirrors SwiftUI backend: adjust offset by content growth delta.
        // Does NOT scroll to bottom even when pinned — prepend is always position-preserving.
        if isPrepend {
            collectionView.layoutIfNeeded()
            let newContentSize = collectionView.contentSize.height
            let delta = newContentSize - capturedContentSize
            if delta > 0 {
                collectionView.setContentOffset(
                    CGPoint(x: 0, y: capturedOffsetY + delta),
                    animated: false
                )
            } else {
                // Fallback: estimate from average row height
                let prependedCount = newCount - previousCount
                let avgHeight = capturedContentSize / CGFloat(max(previousCount, 1))
                let estimate = CGFloat(prependedCount) * avgHeight
                collectionView.setContentOffset(
                    CGPoint(x: 0, y: capturedOffsetY + estimate),
                    animated: false
                )
            }
            controller.prependInFlight = false
        }

        // Auto-scroll on append when pinned — mirrors SwiftUI backend's behavior.
        // Uses autoScrollPending to handle burst appends (multiple rapid appends).
        if isAppend && wasPinned {
            controller.autoScrollPending = true
            collectionView.layoutIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak controller] in
                controller?.scrollToBottom(animated: newCount - previousCount <= 5)
                controller?.autoScrollPending = false
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

        public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            // Clear programmatic scroll guard after animated scroll completes
            controller.programmaticScrollInFlight = false
            controller.updateBottomPinState()
        }

        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            controller.updateBottomPinState()
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
