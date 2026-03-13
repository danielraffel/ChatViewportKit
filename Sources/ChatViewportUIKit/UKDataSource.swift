import UIKit
import SwiftUI

/// Bridges a RandomAccessCollection to a NSDiffableDataSourceSnapshot for UICollectionView.
///
/// Wraps each item's ID as a Hashable identifier and uses a single section.
/// Provides `indexPath(for:)` so the controller can locate items for scrollTo.
final class UKDataSource<Data, ID, RowContent>: UKDataSourceBase<ID>
where Data: RandomAccessCollection, ID: Hashable, RowContent: View {

    private enum Section: Hashable {
        case main
    }

    /// Wrapper to make item IDs usable as diffable data source item identifiers.
    private struct ItemIdentifier: Hashable {
        let id: ID
    }

    private let idKeyPath: KeyPath<Data.Element, ID>
    private let rowContent: (Data.Element) -> RowContent

    /// Map from ID to the actual data element for cell configuration.
    private var elementsByID: [ID: Data.Element] = [:]

    /// Ordered IDs for indexPath lookup.
    private var orderedIDs: [ID] = []

    private var diffableDataSource: UICollectionViewDiffableDataSource<Section, ItemIdentifier>?

    init(
        collectionView: UICollectionView,
        idKeyPath: KeyPath<Data.Element, ID>,
        rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.idKeyPath = idKeyPath
        self.rowContent = rowContent
        super.init()

        collectionView.register(UKHostingCell.self, forCellWithReuseIdentifier: UKHostingCell.reuseIdentifier)

        self.diffableDataSource = UICollectionViewDiffableDataSource<Section, ItemIdentifier>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, itemIdentifier in
            guard let self = self else { return nil }
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: UKHostingCell.reuseIdentifier,
                for: indexPath
            ) as! UKHostingCell

            if let element = self.elementsByID[itemIdentifier.id] {
                cell.configure(with: self.rowContent(element))
            }

            return cell
        }
    }

    /// Apply new data to the collection view via diffable data source.
    func apply(data: Data, animated: Bool = false) {
        // Update element lookup
        elementsByID.removeAll(keepingCapacity: true)
        orderedIDs.removeAll(keepingCapacity: true)
        for element in data {
            let id = element[keyPath: idKeyPath]
            elementsByID[id] = element
            orderedIDs.append(id)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemIdentifier>()
        snapshot.appendSections([.main])
        snapshot.appendItems(orderedIDs.map { ItemIdentifier(id: $0) }, toSection: .main)

        // Reconfigure items that already exist so content/height mutations
        // (Expand, Grow, Dynamic Type) are picked up. reconfigureItems only
        // re-renders visible cells, so this is efficient even at 10K+ items.
        if let existing = diffableDataSource?.snapshot() {
            let existingSet = Set(existing.itemIdentifiers)
            let toReconfigure = snapshot.itemIdentifiers.filter { existingSet.contains($0) }
            if !toReconfigure.isEmpty {
                snapshot.reconfigureItems(toReconfigure)
            }
        }

        diffableDataSource?.apply(snapshot, animatingDifferences: animated)
    }

    /// Reconfigure visible cells without a full snapshot apply.
    /// Use after in-place data mutations (height changes, content updates).
    func reconfigure(ids: [ID]) {
        guard var snapshot = diffableDataSource?.snapshot() else { return }
        let items = ids.map { ItemIdentifier(id: $0) }
        snapshot.reconfigureItems(items)
        diffableDataSource?.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - UKDataSourceBase

    override func indexPath(for id: ID) -> IndexPath? {
        guard let index = orderedIDs.firstIndex(of: id) else { return nil }
        return IndexPath(item: index, section: 0)
    }

    /// Get the ID at a given index path.
    func id(at indexPath: IndexPath) -> ID? {
        guard indexPath.item >= 0 && indexPath.item < orderedIDs.count else { return nil }
        return orderedIDs[indexPath.item]
    }

    var itemCount: Int { orderedIDs.count }
}
