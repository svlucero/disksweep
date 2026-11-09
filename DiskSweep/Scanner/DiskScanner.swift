import Foundation

/// Walks a configured volume root to depth 2 and reports the directories found,
/// sorted by size descending. Runs entirely off the main thread.
actor DiskScanner {

    /// Maximum depth, relative to the configured root, that is scanned.
    /// Depth 1 == direct children of the volume root; depth 2 == grandchildren.
    static let maxDepth = 2

    private let fileManager: FileManager
    nonisolated let rootURL: URL
    private let mountedVolumePaths: Set<String>

    init(
        fileManager: FileManager = .default,
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.rootURL = rootURL
        let mountedURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        self.mountedVolumePaths = Set(mountedURLs.map { $0.standardizedFileURL.path })
    }

    /// Scans the root directory to `maxDepth`, returning directories sorted by
    /// size descending.
    ///
    /// - Parameter progress: Called on the actor with a value in `0.0...1.0` as
    ///   the scan advances. Useful for driving a progress bar.
    func scan(progress: (@Sendable (Double) -> Void)? = nil) -> [DiskItem] {
        // Collect the top-level directories first so we can report meaningful
        // progress as each one is fully measured.
        let topLevel = directories(in: rootURL)
        guard !topLevel.isEmpty else {
            progress?(1.0)
            return []
        }

        var items: [DiskItem] = []
        let total = Double(topLevel.count)

        for (index, dir) in topLevel.enumerated() {
            items.append(contentsOf: collect(at: dir, depth: 1))
            progress?(Double(index + 1) / total)
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Lists the immediate children (files and directories) of `url`, each with
    /// its size, sorted by size descending. Directories report their total size
    /// on disk; files report their own size. Used for lazy tree navigation.
    func children(of url: URL) -> [DiskEntry] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        var entries: [DiskEntry] = []
        for child in contents {
            guard !isNestedMountPoint(child) else { continue }
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let size = isDir ? (directorySize(at: child) ?? 0) : fileSize(at: child)
            entries.append(
                DiskEntry(
                    url: child,
                    name: child.lastPathComponent,
                    size: size,
                    isDirectory: isDir
                )
            )
        }
        return entries.sorted { $0.size > $1.size }
    }

    // MARK: - Private

    /// Size of a single regular file (allocated, falling back to logical).
    private func fileSize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .totalFileSizeKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        let size = values.totalFileAllocatedSize ?? values.totalFileSize ?? values.fileSize ?? 0
        return Int64(size)
    }

    /// Recursively collects directory items at `url` and, while within depth,
    /// its subdirectories.
    private func collect(at url: URL, depth: Int) -> [DiskItem] {
        var result: [DiskItem] = []

        if let item = makeItem(for: url) {
            result.append(item)
        }

        if depth < Self.maxDepth {
            for child in directories(in: url) {
                result.append(contentsOf: collect(at: child, depth: depth + 1))
            }
        }

        return result
    }

    /// Returns the immediate subdirectories of `url`, skipping files,
    /// permission-denied entries, and anything unreadable.
    private func directories(in url: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        return contents.filter { child in
            guard !isNestedMountPoint(child) else { return false }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory == true
        }
    }

    /// Builds a `DiskItem` for a directory, measuring its total size on disk.
    /// Returns `nil` when the size can't be determined (permission denied,
    /// symlink, etc.) so the caller can skip it.
    private func makeItem(for url: URL) -> DiskItem? {
        guard let size = directorySize(at: url) else { return nil }

        return DiskItem(
            url: url,
            name: url.lastPathComponent,
            parentLabel: parentLabel(for: url),
            size: size
        )
    }

    /// Sums the `.totalFileAllocatedSize` (falling back to `.totalFileSize`) of
    /// every file under `url`. Returns `nil` if the directory can't be
    /// enumerated at all.
    private func directorySize(at url: URL) -> Int64? {
        let keys: [URLResourceKey] = [.totalFileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true } // skip individual errors, keep going
        ) else {
            return nil
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                if isNestedMountPoint(fileURL) { enumerator.skipDescendants() }
                continue
            }
            let size = values.totalFileAllocatedSize ?? values.totalFileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    /// Prevents a scan of one volume from traversing another volume mounted below it.
    private func isNestedMountPoint(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path != rootURL.standardizedFileURL.path && mountedVolumePaths.contains(path)
    }

    /// An abbreviated label for the parent directory, relative to the scan root.
    private func parentLabel(for url: URL) -> String {
        let parent = url.deletingLastPathComponent()
        let rootPath = rootURL.standardizedFileURL.path
        let parentPath = parent.standardizedFileURL.path

        if parentPath == rootPath {
            return "./"
        }
        if parentPath.hasPrefix(rootPath == "/" ? "/" : rootPath + "/") {
            let prefix = rootPath == "/" ? 1 : rootPath.count + 1
            let relative = String(parentPath.dropFirst(prefix))
            return relative + "/"
        }
        return parent.lastPathComponent + "/"
    }
}
