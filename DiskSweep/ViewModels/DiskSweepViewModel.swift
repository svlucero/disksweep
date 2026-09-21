import Foundation
import SwiftUI

/// Selectable size thresholds shown in the toolbar picker.
enum SizeThreshold: Int64, CaseIterable, Identifiable {
    case mb10 = 10_000_000
    case mb50 = 50_000_000
    case mb100 = 100_000_000
    case mb500 = 500_000_000
    case gb1 = 1_000_000_000

    var id: Int64 { rawValue }

    /// Bytes represented by this threshold.
    var bytes: Int64 { rawValue }

    var label: String {
        switch self {
        case .mb10: return "10 MB"
        case .mb50: return "50 MB"
        case .mb100: return "100 MB"
        case .mb500: return "500 MB"
        case .gb1: return "1 GB"
        }
    }

    static let `default`: SizeThreshold = .mb50
}

/// Current state of a scan.
enum ScanState: Equatable {
    case idle
    case scanning
    case done
    case error(String)
}

/// Snapshot of the volume's capacity.
struct DiskUsage: Equatable {
    let total: Int64
    let free: Int64

    var used: Int64 { max(0, total - free) }
    var percentUsed: Int { total > 0 ? Int((Double(used) / Double(total) * 100).rounded()) : 0 }

    var freeFormatted: String { ByteFormatter.string(fromByteCount: free) }
}

@MainActor
final class DiskSweepViewModel: ObservableObject {

    /// Full, unfiltered scan results (sorted by size descending).
    @Published private(set) var allItems: [DiskItem] = []
    /// Threshold currently selected by the user. Re-filters the tree instantly.
    @Published var threshold: SizeThreshold = .default {
        didSet { if oldValue != threshold { rebuildRoots() } }
    }
    /// State of the most recent scan.
    @Published private(set) var scanState: ScanState = .idle
    /// Scan progress in `0.0...1.0`.
    @Published private(set) var scanProgress: Double = 0.0
    /// Current disk usage summary, refreshed after each scan and delete.
    @Published private(set) var diskUsage: DiskUsage?
    /// Error to surface to the user (e.g. a failed delete).
    @Published var deleteError: String?

    /// Top-level nodes of the navigable tree (filtered by threshold). Scan
    /// results nested below another result are revealed when their parent is
    /// expanded, so each location appears only once in the tree.
    @Published private(set) var rootNodes: [FileNode] = []
    /// IDs of the nodes the user has selected. Bound to the `List` selection.
    @Published var selection = Set<FileNode.ID>()
    /// Bumped to force the `List` to recompute `visibleNodes` after a node's
    /// expansion or children change (those live on `FileNode`, not here).
    @Published private(set) var revision = 0

    /// Flat index of every loaded node by id, for selection lookups.
    private var nodesByID: [FileNode.ID: FileNode] = [:]

    private let scanner: DiskScanner
    private let fileManager: FileManager
    private let homeURL: URL

    init(
        scanner: DiskScanner = DiskScanner(),
        fileManager: FileManager = .default,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.scanner = scanner
        self.fileManager = fileManager
        self.homeURL = homeURL
        refreshDiskUsage()
    }

    /// Items above the current threshold. Recomputed instantly when the
    /// threshold changes — no re-scan needed.
    var filteredItems: [DiskItem] {
        let limit = threshold.bytes
        return allItems.filter { $0.size >= limit }
    }

    var isScanning: Bool {
        if case .scanning = scanState { return true }
        return false
    }

    /// The visible rows of the tree: each expanded node followed by its loaded
    /// children, depth-first. The threshold also filters children — entries
    /// below it are hidden at every level, not just the top level.
    var visibleNodes: [FileNode] {
        let limit = threshold.bytes
        var out: [FileNode] = []
        func walk(_ nodes: [FileNode]) {
            for node in nodes where node.size >= limit {
                out.append(node)
                if node.isExpanded, let children = node.children {
                    walk(children)
                }
            }
        }
        walk(rootNodes)
        return out
    }

    // MARK: - Selection summary

    /// Selected nodes, de-duplicated so a node nested inside another selected
    /// node is dropped (deleting the ancestor already removes it).
    var effectiveSelection: [FileNode] {
        let selected = selection.compactMap { nodesByID[$0] }
        return selected.filter { node in
            !selected.contains { other in
                other.id != node.id && isDescendant(node.url, of: other.url)
            }
        }
    }

    var selectedCount: Int { effectiveSelection.count }

    var selectedTotalSize: Int64 {
        effectiveSelection.reduce(0) { $0 + $1.size }
    }

    /// Full path of the selected node when exactly one is selected, abbreviated
    /// with `~` for the home directory. `nil` for zero or multiple selections.
    var selectedPath: String? {
        guard let node = effectiveSelection.first, effectiveSelection.count == 1 else { return nil }
        return (node.url.path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - Scanning

    func scan() async {
        scanState = .scanning
        scanProgress = 0.0

        let results = await scanner.scan { [weak self] value in
            Task { @MainActor in self?.scanProgress = value }
        }

        allItems = results
        scanProgress = 1.0
        scanState = .done
        rebuildRoots()
        refreshDiskUsage()
    }

    // MARK: - Tree navigation

    /// Expands or collapses a directory node, lazily loading its children the
    /// first time it is opened.
    func toggleExpand(_ node: FileNode) async {
        guard node.isDirectory else { return }
        node.isExpanded.toggle()
        revision += 1

        guard node.isExpanded, node.children == nil else { return }

        node.isLoading = true
        revision += 1

        let entries = await scanner.children(of: node.url)
        let children = entries.map { FileNode(entry: $0, depth: node.depth + 1) }
        for child in children { nodesByID[child.id] = child }

        node.children = children
        node.isLoading = false
        revision += 1
    }

    // MARK: - Deletion

    /// Hard-deletes every selected node from disk (no Trash), then removes it
    /// from the tree. Failures are reported via `deleteError`.
    func deleteSelected() {
        for node in effectiveSelection {
            do {
                try fileManager.removeItem(at: node.url)
                removeNodeFromTree(node)
                purge(node)
            } catch {
                deleteError = "Could not delete \(node.name): \(error.localizedDescription)"
            }
        }
        revision += 1
        refreshDiskUsage()
    }

    // MARK: - Disk usage

    func refreshDiskUsage() {
        guard let values = try? homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) else {
            diskUsage = nil
            return
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        diskUsage = DiskUsage(total: total, free: free)
    }

    // MARK: - Testing

    /// Injects scan results directly, bypassing a real scan.
    func setItemsForTesting(_ items: [DiskItem]) {
        allItems = items.sorted { $0.size > $1.size }
        scanState = .done
        rebuildRoots()
    }

    // MARK: - Private

    /// Rebuilds the top-level nodes from the current filtered items, resetting
    /// expansion, selection, and the node index. The scanner includes
    /// directories at two depths, but nested results are not roots: expanding
    /// their parent loads them at the correct location in the hierarchy.
    private func rebuildRoots() {
        let scannedPaths = Set(allItems.map { $0.url.standardizedFileURL.path })
        let roots = filteredItems
            .filter { item in
                !scannedPaths.contains(item.url.deletingLastPathComponent().standardizedFileURL.path)
            }
            .map { FileNode(item: $0, depth: 0) }
        rootNodes = roots
        nodesByID = Dictionary(uniqueKeysWithValues: roots.map { ($0.id, $0) })
        selection = []
        revision += 1
    }

    /// True when `a` lives inside the directory `b`.
    private func isDescendant(_ a: URL, of b: URL) -> Bool {
        let aPath = a.standardizedFileURL.path
        let bPath = b.standardizedFileURL.path
        return aPath.hasPrefix(bPath + "/")
    }

    /// Removes a node from the tree and every matching scanned descendant.
    private func removeNodeFromTree(_ target: FileNode) {
        if let index = rootNodes.firstIndex(where: { $0.id == target.id }) {
            rootNodes.remove(at: index)
        } else {
            _ = removeFromChildren(of: rootNodes, target: target)
        }

        let targetPath = target.url.standardizedFileURL.path
        allItems.removeAll { item in
            let itemPath = item.url.standardizedFileURL.path
            return itemPath == targetPath || itemPath.hasPrefix(targetPath + "/")
        }
    }

    @discardableResult
    private func removeFromChildren(of nodes: [FileNode], target: FileNode) -> Bool {
        for node in nodes {
            guard var children = node.children else { continue }
            if let index = children.firstIndex(where: { $0.id == target.id }) {
                children.remove(at: index)
                node.children = children
                return true
            }
            if removeFromChildren(of: children, target: target) { return true }
        }
        return false
    }

    /// Removes a node and its descendants from the selection and the index.
    private func purge(_ node: FileNode) {
        selection.remove(node.id)
        nodesByID[node.id] = nil
        node.children?.forEach(purge)
    }
}
