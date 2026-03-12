import UIKit
import SwiftUI

/// A UICollectionViewCell that hosts SwiftUI content via UIHostingConfiguration.
///
/// Uses UIHostingConfiguration (iOS 16+) for efficient SwiftUI cell rendering.
/// The configuration is applied directly — no manual hosting controller management.
final class UKHostingCell: UICollectionViewCell {

    static let reuseIdentifier = "UKHostingCell"

    /// Apply SwiftUI content to this cell using UIHostingConfiguration.
    func configure<Content: View>(with content: Content) {
        self.contentConfiguration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)
    }
}
