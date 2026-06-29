import Foundation
import Combine

/// A node in the navigable file tree. Reference type so the UI can observe
/// expansion and lazy-loaded children without rebuilding the whole tree.
@MainActor
final class FileNode: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    /// Indentation level in the tree (0 == top-level scan result).
    let depth: Int

    @Published var size: Int64
    @Published var isExpanded = false
    /// `nil` until the children have been loaded (lazy).
    @Published var children: [FileNode]?
    @Published var isLoading = false

    init(url: URL, name: String, isDirectory: Bool, size: Int64, depth: Int) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.depth = depth
    }

    /// Builds a top-level node from a scan result.
    convenience init(item: DiskItem, depth: Int) {
        self.init(url: item.url, name: item.name, isDirectory: true, size: item.size, depth: depth)
    }

    /// Builds a child node from a scanned entry.
    convenience init(entry: DiskEntry, depth: Int) {
        self.init(url: entry.url, name: entry.name, isDirectory: entry.isDirectory, size: entry.size, depth: depth)
    }

    var formattedSize: String { ByteFormatter.string(fromByteCount: size) }
}
