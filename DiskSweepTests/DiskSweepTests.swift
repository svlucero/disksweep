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

    @MainActor
    func testThresholdHidesChildrenBelowLimit() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("disksweep-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // Top-level dir "big" with a 12 MB file (above) and a 1 MB file (below).
        let big = root.appendingPathComponent("big")
        try fm.createDirectory(at: big, withIntermediateDirectories: true)
        try Data(count: 12_000_000).write(to: big.appendingPathComponent("large.bin"))
        try Data(count: 1_000_000).write(to: big.appendingPathComponent("tiny.bin"))

        let vm = DiskSweepViewModel(scanner: DiskScanner(rootURL: root))
        vm.threshold = .mb10
        await vm.scan()

        // Expand the top-level node.
        let rootNode = try XCTUnwrap(vm.visibleNodes.first { $0.name == "big" })
        await vm.toggleExpand(rootNode)

        let visibleNames = vm.visibleNodes.map(\.name)
        XCTAssertTrue(visibleNames.contains("large.bin"), "Expected the 12 MB file to show")
        XCTAssertFalse(visibleNames.contains("tiny.bin"), "1 MB file should be hidden below 10 MB threshold")
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

    // MARK: - Tree navigation (children)

    func testChildrenListsFilesAndDirectoriesSortedBySize() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("disksweep-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // A subdirectory (big) and a loose file (small).
        let sub = root.appendingPathComponent("subdir")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(count: 8_000).write(to: sub.appendingPathComponent("inner.bin"))
        try Data(count: 1_000).write(to: root.appendingPathComponent("file.bin"))

        let scanner = DiskScanner(rootURL: root)
        let children = await scanner.children(of: root)

        XCTAssertEqual(children.map(\.name), ["subdir", "file.bin"])
        XCTAssertTrue(children[0].isDirectory)
        XCTAssertFalse(children[1].isDirectory)
        XCTAssertGreaterThan(children[0].size, children[1].size)
    }

    func testChildrenOfFileOrMissingPathIsEmpty() async throws {
        let scanner = DiskScanner()
        let missing = URL(fileURLWithPath: "/tmp/disksweep-does-not-exist-\(UUID().uuidString)")
        let children = await scanner.children(of: missing)
        XCTAssertTrue(children.isEmpty)
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
