import SwiftUI

/// Controller for imperative scroll commands on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject {

    // MARK: - Internal state (set by ChatViewport)
    internal var scrollProxy: ScrollViewProxy?
    internal var firstItemID: ID?
    internal var lastItemID: ID?

    public init() {}

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        guard let id = lastItemID, let proxy = scrollProxy else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    public func scrollToTop(animated: Bool = true) {
        guard let id = firstItemID, let proxy = scrollProxy else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(id, anchor: .top)
            }
        } else {
            proxy.scrollTo(id, anchor: .top)
        }
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
