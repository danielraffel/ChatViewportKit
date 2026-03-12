import SwiftUI

// MARK: - Content Height Preference

/// Preference key to capture the total content height of the LazyVStack.
struct ContentHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Offset Preference

/// Preference key to capture the scroll offset (distance from content top to viewport top).
struct ScrollOffsetPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Row Frame Capture

/// A captured frame for a single row, in the ScrollView's coordinate space.
struct RowFrame<ID: Hashable>: Equatable {
    let id: ID
    let minY: CGFloat
    let maxY: CGFloat

    var height: CGFloat { maxY - minY }
}

/// Preference key that collects visible row frames.
struct RowFramesPreference<ID: Hashable>: PreferenceKey {
    static var defaultValue: [RowFrame<ID>] { [] }
    static func reduce(value: inout [RowFrame<ID>], nextValue: () -> [RowFrame<ID>]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Coordinate Space

/// The coordinate space name used for scroll position tracking.
let viewportCoordinateSpace = "ChatViewportCoordinateSpace"
