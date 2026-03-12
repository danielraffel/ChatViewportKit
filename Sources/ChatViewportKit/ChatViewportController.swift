import SwiftUI

/// Controller for imperative scroll commands on a `ChatViewport`.
public final class ChatViewportController<ID: Hashable>: ObservableObject {

    // MARK: - Published command (consumed by ChatViewport's body)
    @Published internal var pendingCommand: ScrollCommand<ID>?

    // MARK: - Internal state (set by ChatViewport)
    internal var firstItemID: ID?
    internal var lastItemID: ID?

    /// Whether the controller has been connected (debug use).
    public var isConnected: Bool { true }

    /// The last item ID tracked by the controller (debug use).
    public var debugLastItemID: ID? { lastItemID }

    public init() {}

    // MARK: - Public API

    public func scrollToBottom(animated: Bool = true) {
        guard let id = lastItemID else { return }
        pendingCommand = .scrollTo(id: id, anchor: .bottom, animated: animated)
    }

    public func scrollToTop(animated: Bool = true) {
        guard let id = firstItemID else { return }
        pendingCommand = .scrollTo(id: id, anchor: .top, animated: animated)
    }

    public func scrollTo(id: ID, anchor: UnitPoint = .center, animated: Bool = true) {
        pendingCommand = .scrollTo(id: id, anchor: anchor, animated: animated)
    }
}

// MARK: - Scroll Command

internal enum ScrollCommand<ID: Hashable>: Equatable {
    case scrollTo(id: ID, anchor: UnitPoint, animated: Bool)

    static func == (lhs: ScrollCommand, rhs: ScrollCommand) -> Bool {
        switch (lhs, rhs) {
        case let (.scrollTo(lID, lAnchor, lAnimated), .scrollTo(rID, rAnchor, rAnimated)):
            return lID == rID && lAnchor == rAnchor && lAnimated == rAnimated
        }
    }
}
