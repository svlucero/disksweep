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

    func testDiskUsageFormatsTotalCapacity() {
        let usage = DiskUsage(total: 1_000_000_000, free: 250_000_000)

        XCTAssertEqual(usage.totalFormatted, ByteFormatter.string(fromByteCount: 1_000_000_000))
    }

    // MARK: - Persistent folder access

    func testFolderAccessBookmarkRestoresAndCanBeCleared() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("disksweep-bookmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let suiteName = "DiskSweepTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FolderAccessStore(defaults: defaults)
        let volumeID = "/Volumes/Fixture"

        try store.save(root, forVolumeID: volumeID)
        XCTAssertEqual(store.restore(forVolumeID: volumeID)?.standardizedFileURL, root.standardizedFileURL)

        store.clear(forVolumeID: volumeID)
        XCTAssertNil(store.restore(forVolumeID: volumeID))
    }

    func testFolderAccessGrantExpiresAfterOneCalendarMonthAndIsPerVolume() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("disksweep-expiring-bookmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let suiteName = "DiskSweepTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FolderAccessStore(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let grantDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12))!
        let expirationDate = calendar.date(byAdding: .month, value: 1, to: grantDate)!

        try store.save(root, forVolumeID: "/Volumes/Fixture", at: grantDate)
        try store.save(root, forVolumeID: "/Volumes/Another", at: grantDate)

        XCTAssertEqual(
            store.restore(forVolumeID: "/Volumes/Fixture", at: expirationDate.addingTimeInterval(-1), calendar: calendar)?.standardizedFileURL,
            root.standardizedFileURL
        )
        XCTAssertEqual(
            store.restore(forVolumeID: "/Volumes/Another", at: expirationDate.addingTimeInterval(-1), calendar: calendar)?.standardizedFileURL,
            root.standardizedFileURL
        )
        XCTAssertNil(store.restore(forVolumeID: "/Volumes/Fixture", at: expirationDate, calendar: calendar))
        XCTAssertNil(store.restore(forVolumeID: "/Volumes/Another", at: expirationDate, calendar: calendar))
    }

    @MainActor
    func testFolderMustBeGrantedBeforeProductionScanAndCanBeRemembered() async throws {
        let root = try makeTempTree([("folder", 2_000)])
        defer { try? FileManager.default.removeItem(at: root) }

        let suiteName = "DiskSweepTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FolderAccessStore(defaults: defaults)
        let vm = DiskSweepViewModel(
            fileManager: .default,
            homeURL: root,
            volumes: [DiskVolume(url: root, name: "Fixture")],
            folderAccessStore: store
        )

        XCTAssertFalse(vm.hasFolderAccess)
        XCTAssertNotNil(vm.diskUsage, "Volume capacity should be available before folder scan access is granted.")
        let deniedScan = await vm.scan()
        XCTAssertEqual(deniedScan, .authorizationRequired)
        XCTAssertEqual(vm.scanState, .idle)
        XCTAssertTrue(vm.allItems.isEmpty)

        XCTAssertTrue(vm.authorizeFolder(root))
        XCTAssertTrue(vm.hasFolderAccess)
        XCTAssertEqual(store.restore(forVolumeID: root.standardizedFileURL.path)?.standardizedFileURL, root.standardizedFileURL)
        let firstScan = await vm.scan()
        XCTAssertEqual(firstScan, .scanned)
        XCTAssertEqual(vm.allItems.map(\.name), ["folder"])

        let relaunchedVM = DiskSweepViewModel(
            fileManager: .default,
            homeURL: root,
            volumes: [DiskVolume(url: root, name: "Fixture")],
            folderAccessStore: store
        )
        XCTAssertFalse(relaunchedVM.hasFolderAccess, "A saved grant is activated when the user starts a scan.")
        XCTAssertEqual(relaunchedVM.selectedVolume.url.standardizedFileURL, root.standardizedFileURL)
        let relaunchedScan = await relaunchedVM.scan()
        XCTAssertEqual(relaunchedScan, .scanned)
        XCTAssertTrue(relaunchedVM.hasFolderAccess)
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

    @MainActor
    func testNestedScanResultAppearsOnlyUnderItsParent() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("disksweep-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let parent = root.appendingPathComponent("parent")
        let child = parent.appendingPathComponent("child")
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        try Data(count: 12_000_000).write(to: child.appendingPathComponent("payload.bin"))

        let vm = DiskSweepViewModel(scanner: DiskScanner(rootURL: root))
        vm.threshold = .mb10
        await vm.scan()

        XCTAssertEqual(vm.rootNodes.map(\.name), ["parent"])

        let parentNode = try XCTUnwrap(vm.rootNodes.first)
        await vm.toggleExpand(parentNode)

        XCTAssertEqual(vm.visibleNodes.map(\.name), ["parent", "child"])
        XCTAssertEqual(vm.visibleNodes.last?.depth, 1)
    }

    @MainActor
    func testSelectingVolumeScansItsRootAndClearsPreviousResults() async throws {
        let firstRoot = try makeTempTree([("first", 2_000)])
        let secondRoot = try makeTempTree([("second", 3_000)])
        defer {
            try? FileManager.default.removeItem(at: firstRoot)
            try? FileManager.default.removeItem(at: secondRoot)
        }

        let firstVolume = DiskVolume(url: firstRoot, name: "First")
        let secondVolume = DiskVolume(url: secondRoot, name: "Second")
        let vm = DiskSweepViewModel(
            volumes: [firstVolume, secondVolume],
            initialVolumeURL: firstRoot
        )
        XCTAssertEqual(Set(vm.volumes), Set([firstVolume, secondVolume]))

        await vm.scan()
        XCTAssertEqual(vm.allItems.map(\.name), ["first"])

        vm.selectVolume(secondVolume)
        XCTAssertTrue(vm.allItems.isEmpty)
        XCTAssertEqual(vm.scanState, .idle)
        XCTAssertEqual(vm.selectedVolume, secondVolume)

        await vm.scan()
        XCTAssertEqual(vm.allItems.map(\.name), ["second"])
    }

    @MainActor
    func testExpiredVolumeGrantRequestsAuthorizationAgainWhenScanning() async throws {
        let root = try makeTempTree([("folder", 2_000)])
        defer { try? FileManager.default.removeItem(at: root) }

        let suiteName = "DiskSweepTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let volumeID = root.standardizedFileURL.path
        let store = FolderAccessStore(defaults: defaults)
        let expiredGrantDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        try store.save(root, forVolumeID: volumeID, at: expiredGrantDate)
        let vm = DiskSweepViewModel(
            homeURL: root,
            volumes: [DiskVolume(url: root, name: "Fixture")],
            folderAccessStore: store
        )

        let result = await vm.scan()
        XCTAssertEqual(result, .authorizationRequired)
        XCTAssertFalse(vm.hasFolderAccess)
        XCTAssertEqual(vm.scanState, .idle)
    }

    func testMountedVolumesOnlyContainsBrowsableVolumes() {
        let volumes = DiskVolume.mounted()

        XCTAssertTrue(volumes.allSatisfy { volume in
            (try? volume.url.resourceValues(forKeys: [.volumeIsBrowsableKey]))?.volumeIsBrowsable == true
        })
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
