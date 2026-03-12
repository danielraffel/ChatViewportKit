import SwiftUI
import UIKit

/// A transparent overlay that finds the hosting UIScrollView and provides
/// direct access to contentOffset for pixel-precise scroll corrections.
///
/// Rules:
/// - Only reads/writes contentOffset — never modifies contentSize, delegate, or subviews
/// - The SwiftUI ScrollView + LazyVStack remains the only render tree
/// - Not exposed in the public API
struct ScrollViewBridge: UIViewRepresentable {
    let onScrollViewFound: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ScrollViewFinderView()
        view.onScrollViewFound = onScrollViewFound
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class ScrollViewFinderView: UIView {
    var onScrollViewFound: ((UIScrollView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let scrollView = self?.findScrollView() else { return }
            self?.onScrollViewFound?(scrollView)
        }
    }

    private func findScrollView() -> UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}
