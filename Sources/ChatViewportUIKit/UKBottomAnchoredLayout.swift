import UIKit

/// A UICollectionViewFlowLayout subclass that pushes content to the bottom
/// when content is shorter than the collection view (underfilled state).
///
/// Same visual behavior as LazyVStack's `.frame(minHeight:, alignment: .bottom)`.
/// When content overflows, layout behaves normally (standard top-aligned flow).
final class UKBottomAnchoredLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        guard let cv = collectionView else { return attributes }

        let contentHeight = collectionViewContentSize.height
        let viewportHeight = cv.bounds.height - cv.adjustedContentInset.top - cv.adjustedContentInset.bottom

        // Only shift when underfilled
        guard contentHeight < viewportHeight else { return attributes }

        let offset = viewportHeight - contentHeight
        return attributes.map { attr in
            let shifted = attr.copy() as! UICollectionViewLayoutAttributes
            shifted.frame = shifted.frame.offsetBy(dx: 0, dy: offset)
            return shifted
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attr = super.layoutAttributesForItem(at: indexPath) else { return nil }
        guard let cv = collectionView else { return attr }

        let contentHeight = collectionViewContentSize.height
        let viewportHeight = cv.bounds.height - cv.adjustedContentInset.top - cv.adjustedContentInset.bottom

        guard contentHeight < viewportHeight else { return attr }

        let offset = viewportHeight - contentHeight
        let shifted = attr.copy() as! UICollectionViewLayoutAttributes
        shifted.frame = shifted.frame.offsetBy(dx: 0, dy: offset)
        return shifted
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let cv = collectionView else { return true }
        // Invalidate when size changes (keyboard show/hide, rotation)
        return cv.bounds.size != newBounds.size
    }
}
