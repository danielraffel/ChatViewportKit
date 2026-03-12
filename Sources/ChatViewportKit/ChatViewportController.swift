import SwiftUI

/// Controller for imperative scroll commands on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject {

    // MARK: - Internal scroll proxy (set by ChatViewport on appear)
    internal var scrollProxy: ScrollViewProxy?

    public init() {}

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        // Will be wired to actual last-item ID once data binding is in place
    }

    public func scrollToTop(animated: Bool = true) {
        // Will be wired to actual first-item ID once data binding is in place
    }

    public func scrollTo(id: ID, anchor: UnitPoint = .center, animated: Bool = true) {
        guard let proxy = scrollProxy else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(id, anchor: anchor)
            }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}
