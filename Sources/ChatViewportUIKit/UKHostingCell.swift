import UIKit
import SwiftUI

/// A UICollectionViewCell that hosts SwiftUI content via UIHostingConfiguration.
///
/// Uses UIHostingConfiguration (iOS 16+) for efficient SwiftUI cell rendering.
/// Forces full-width layout by constraining content view width to collection view width.
final class UKHostingCell: UICollectionViewCell {

    static let reuseIdentifier = "UKHostingCell"

    private var widthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Pin content view width to cell width for full-width self-sizing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Apply SwiftUI content to this cell using UIHostingConfiguration.
    func configure<Content: View>(with content: Content) {
        self.contentConfiguration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        // Force full width from the collection view, self-size only height
        guard let cv = superview as? UICollectionView else {
            return super.preferredLayoutAttributesFitting(layoutAttributes)
        }
        let targetWidth = cv.bounds.width - cv.contentInset.left - cv.contentInset.right
        layoutAttributes.frame.size.width = targetWidth

        // Let auto layout determine the height
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.frame.size.height = max(size.height, 1)
        return layoutAttributes
    }
}
