import SwiftUI

// MARK: - Content Height Preference

/// Preference key to capture the total content height of the LazyVStack.
struct ContentHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Scroll Offset Preference

/// Preference key to capture the scroll offset (distance from content top to viewport top).
struct ScrollOffsetPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
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

/// Preference key that folds visible row frames down to the single topmost visible row.
/// Only rows with maxY > 0 (visible in viewport) are candidates.
/// This avoids accumulating all rows into an array and sorting — O(1) per reduce call.
struct RowFramesPreference<ID: Hashable>: PreferenceKey {
    static var defaultValue: [RowFrame<ID>] { [] }
    static func reduce(value: inout [RowFrame<ID>], nextValue: () -> [RowFrame<ID>]) {
        for frame in nextValue() {
            guard frame.maxY > 0 else { continue }
            if let current = value.first {
                if frame.minY < current.minY {
                    value = [frame]
                }
            } else {
                value = [frame]
            }
        }
    }
}

// MARK: - Coordinate Space

/// The coordinate space name used for scroll position tracking.
let viewportCoordinateSpace = "ChatViewportCoordinateSpace"
