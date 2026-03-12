import Foundation

/// Tracks measured row heights for the probe-align scrollTo(id:) engine.
///
/// Heights are recorded from the existing per-row GeometryReader as rows
/// materialize. Unmeasured rows use a running average estimate.
/// The index is rebuilt lazily — only at scrollTo call time.
///
/// Design rules:
/// - Plain property on ChatViewportController, NOT @Published (rule 3)
/// - Reuses existing GeometryReader data, no new views added (rule 6)
/// - Lazy reindex only at scrollTo call time (rule 5)
/// - Invalidate all on data reset and viewport width change
final class HeightIndex<ID: Hashable> {

    // MARK: - Storage

    /// Measured heights keyed by item ID.
    private(set) var heights: [ID: CGFloat] = [:]

    /// Running sum of all measured heights (for computing average).
    private var totalMeasuredHeight: CGFloat = 0

    /// Count of measured items.
    private var measuredCount: Int = 0

    // MARK: - Recording

    /// Record a measured height for a row. Called from the existing per-row GeometryReader.
    /// Skips if the height hasn't changed to avoid unnecessary dictionary writes.
    func record(id: ID, height: CGFloat) {
        guard height > 0 else { return }
        if let existing = heights[id] {
            if abs(existing - height) < 0.5 { return } // no meaningful change
            // Update running totals
            totalMeasuredHeight -= existing
            totalMeasuredHeight += height
            heights[id] = height
        } else {
            heights[id] = height
            totalMeasuredHeight += height
            measuredCount += 1
        }
    }

    /// Remove a specific entry (e.g., when an item is deleted).
    func remove(id: ID) {
        if let removed = heights.removeValue(forKey: id) {
            totalMeasuredHeight -= removed
            measuredCount -= 1
        }
    }

    // MARK: - Queries

    /// Average height across all measured rows. Falls back to a default if nothing measured.
    var averageHeight: CGFloat {
        measuredCount > 0 ? totalMeasuredHeight / CGFloat(measuredCount) : 44
    }

    /// Height for a specific item — measured if available, otherwise estimated.
    func height(for id: ID) -> CGFloat {
        heights[id] ?? averageHeight
    }

    /// Estimated cumulative offset from the top of the content to the top of the target item.
    /// Uses measured heights where available, estimated for unmeasured items.
    ///
    /// - Parameters:
    ///   - targetID: The item to compute offset for.
    ///   - orderedIDs: All item IDs in display order.
    ///   - spacing: Inter-item spacing from configuration.
    /// - Returns: The estimated Y offset from content top to target item top.
    func estimatedOffset(to targetID: ID, in orderedIDs: [ID], spacing: CGFloat) -> CGFloat {
        var offset: CGFloat = 0
        for id in orderedIDs {
            if id == targetID { break }
            offset += height(for: id) + spacing
        }
        return offset
    }

    // MARK: - Invalidation

    /// Clear all cached heights. Call on data reset or viewport width change.
    func invalidateAll() {
        heights.removeAll(keepingCapacity: true)
        totalMeasuredHeight = 0
        measuredCount = 0
    }

    /// Invalidate a specific entry (e.g., after a height mutation).
    func invalidate(id: ID) {
        remove(id: id)
    }
}
