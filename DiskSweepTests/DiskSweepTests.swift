import XCTest
@testable import DiskSweep

final class DiskSweepTests: XCTestCase {

    // MARK: - Byte formatting

    func testByteFormatterUsesDecimalUnits() {
        // 1_000_000_000 bytes is 1 GB in decimal (SI) units, per the spec.
        let formatted = ByteFormatter.string(fromByteCount: 1_000_000_000)
        XCTAssertTrue(formatted.contains("GB"), "Expected GB, got \(formatted)")
    }

    func testFormattedSizeOnDiskItem() {
        let item = makeItem(name: "x", size: 50_000_000)
        XCTAssertTrue(item.formattedSize.contains("MB"), "Expected MB, got \(item.formattedSize)")
    }

    // MARK: - Threshold filtering

    @MainActor
    func testFilteringExcludesItemsBelowThreshold() {
        let vm = DiskSweepViewModel(scanner: DiskScanner())
        vm.setItemsForTesting([
            makeItem(name: "big", size: 200_000_000),
            makeItem(name: "small", size: 20_000_000),
        ])

        vm.threshold = .mb100
        XCTAssertEqual(vm.filteredItems.map(\.name), ["big"])

        vm.threshold = .mb10
        XCTAssertEqual(Set(vm.filteredItems.map(\.name)), ["big", "small"])
    }

    @MainActor
    func testThresholdBoundaryIsInclusive() {
        let vm = DiskSweepViewModel()
        vm.setItemsForTesting([makeItem(name: "exact", size: 50_000_000)])
        vm.threshold = .mb50
        XCTAssertEqual(vm.filteredItems.map(\.name), ["exact"])
    }

    // MARK: - Sorting

    func testScannerSortsBySizeDescending() async throws {
        let root = try makeTempTree([
            ("alpha", 1_000),
            ("beta", 5_000),
            ("gamma", 3_000),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = DiskScanner(rootURL: root)
        let items = await scanner.scan()

        XCTAssertEqual(items.map(\.name), ["beta", "gamma", "alpha"])
        XCTAssertTrue(zip(items, items.dropFirst()).allSatisfy { $0.size >= $1.size })
    }

    // MARK: - Scanner against a fixture

    func testScannerSkipsFilesAndKeepsDirectories() async throws {
        let root = try makeTempTree([("onlydir", 2_000)])
        // Drop a loose file directly under root — should be ignored.
        let loose = root.appendingPathComponent("loose.txt")
        try Data(count: 999).write(to: loose)
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = DiskScanner(rootURL: root)
        let items = await scanner.scan()

        XCTAssertEqual(items.map(\.name), ["onlydir"])
    }

    func testScannerReportsProgressReachingOne() async throws {
        let root = try makeTempTree([("a", 100), ("b", 200)])
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = DiskScanner(rootURL: root)
        actor Box { var last = 0.0; func set(_ v: Double) { last = v } }
        let box = Box()
        _ = await scanner.scan { v in Task { await box.set(v) } }
        // Allow the detached progress tasks to drain.
        try await Task.sleep(nanoseconds: 50_000_000)
        let last = await box.last
        XCTAssertEqual(last, 1.0, accuracy: 0.0001)
    }

    // MARK: - Helpers

    private func makeItem(name: String, size: Int64) -> DiskItem {
        DiskItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            parentLabel: "~/",
            size: size
        )
    }

    /// Builds a temporary directory containing one subdirectory per entry, each
    /// holding a single file of the requested size (bytes).
    private func makeTempTree(_ entries: [(String, Int)]) throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("disksweep-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for (name, size) in entries {
            let dir = root.appendingPathComponent(name)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(count: size).write(to: dir.appendingPathComponent("data.bin"))
        }
        return root
    }
}
