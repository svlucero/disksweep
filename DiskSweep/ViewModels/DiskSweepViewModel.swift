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
    /// Threshold currently selected by the user.
    @Published var threshold: SizeThreshold = .default
    /// State of the most recent scan.
    @Published private(set) var scanState: ScanState = .idle
    /// Scan progress in `0.0...1.0`.
    @Published private(set) var scanProgress: Double = 0.0
    /// Current disk usage summary, refreshed after each scan and delete.
    @Published private(set) var diskUsage: DiskUsage?
    /// Error to surface to the user (e.g. a failed delete).
    @Published var deleteError: String?

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

    /// Items currently checked by the user.
    var selectedItems: [DiskItem] {
        filteredItems.filter(\.isSelected)
    }

    /// Combined size of the selected items.
    var selectedTotalSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var isScanning: Bool {
        if case .scanning = scanState { return true }
        return false
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
        refreshDiskUsage()
    }

    // MARK: - Selection

    func toggleSelection(for item: DiskItem) {
        guard let index = allItems.firstIndex(where: { $0.id == item.id }) else { return }
        allItems[index].isSelected.toggle()
    }

    // MARK: - Deletion

    /// Hard-deletes an item from disk (no Trash), then removes it from the list.
    /// On failure, sets `deleteError` and leaves the item in place.
    func deleteItem(_ item: DiskItem) {
        do {
            try fileManager.removeItem(at: item.url)
            allItems.removeAll { $0.id == item.id }
            refreshDiskUsage()
        } catch {
            deleteError = "No se pudo borrar \(item.name): \(error.localizedDescription)"
        }
    }

    /// Deletes every currently selected item.
    func deleteSelected() {
        for item in selectedItems {
            deleteItem(item)
        }
    }

    // MARK: - Testing

    /// Injects scan results directly, bypassing a real scan. Internal so unit
    /// tests can exercise filtering and selection without touching the disk.
    func setItemsForTesting(_ items: [DiskItem]) {
        allItems = items.sorted { $0.size > $1.size }
        scanState = .done
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
}
