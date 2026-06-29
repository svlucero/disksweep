import Foundation

/// A directory found during a scan of the user's home folder.
struct DiskItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    /// Last path component, e.g. `.android`.
    let name: String
    /// Abbreviated parent path shown in the UI, e.g. `~/` or `Library/`.
    let parentLabel: String
    /// Size in bytes.
    let size: Int64
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        parentLabel: String,
        size: Int64,
        isSelected: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.parentLabel = parentLabel
        self.size = size
        self.isSelected = isSelected
    }
}

/// A lightweight, `Sendable` description of a single entry (file or directory)
/// produced while navigating into an item. Crosses the actor boundary.
struct DiskEntry: Hashable, Sendable {
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
}

extension DiskItem {
    /// Human-readable size, e.g. `17 GB`, `512 MB`.
    var formattedSize: String {
        ByteFormatter.string(fromByteCount: size)
    }
}

/// Formats byte counts using decimal (SI) units, matching the spec's thresholds
/// (where 1 GB == 1_000_000_000 bytes).
enum ByteFormatter {
    static func string(fromByteCount bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
