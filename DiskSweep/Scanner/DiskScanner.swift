import Darwin
import Foundation

enum DiskScannerError: Error, Equatable {
    case accessRequired(URL)
}

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

    /// Scans the root directory to `maxDepth`. If macOS denies access, throws
    /// the affected URL so the UI can direct the user to System Settings.
    func scan(progress: (@Sendable (Double) -> Void)? = nil) throws -> [DiskItem] {
        let topLevel = try directories(in: rootURL)
        guard !topLevel.isEmpty else {
            progress?(1.0)
            return []
        }

        var items: [DiskItem] = []
        let total = Double(topLevel.count)

        for (index, dir) in topLevel.enumerated() {
            items.append(contentsOf: try collect(at: dir, depth: 1))
            progress?(Double(index + 1) / total)
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Lists immediate children and their sizes for lazy tree navigation.
    func children(of url: URL) throws -> [DiskEntry] {
        let contents = try directoryContents(at: url)
        var entries: [DiskEntry] = []

        for child in contents {
            guard !isNestedMountPoint(child) else { continue }
            do {
                let isDirectory = try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                let size = isDirectory
                    ? (try directorySize(at: child) ?? 0)
                    : try fileSize(at: child)
                entries.append(
                    DiskEntry(
                        url: child,
                        name: child.lastPathComponent,
                        size: size,
                        isDirectory: isDirectory
                    )
                )
            } catch let error as DiskScannerError {
                throw error
            } catch {
                if Self.isAccessDenied(error) {
                    throw DiskScannerError.accessRequired(child.deletingLastPathComponent())
                }
            }
        }
        return entries.sorted { $0.size > $1.size }
    }

    // MARK: - Private

    private func fileSize(at url: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .totalFileSizeKey, .fileSizeKey]
        do {
            let values = try url.resourceValues(forKeys: keys)
            let size = values.totalFileAllocatedSize ?? values.totalFileSize ?? values.fileSize ?? 0
            return Int64(size)
        } catch {
            if Self.isAccessDenied(error) {
                throw DiskScannerError.accessRequired(url.deletingLastPathComponent())
            }
            throw error
        }
    }

    private func collect(at url: URL, depth: Int) throws -> [DiskItem] {
        var result: [DiskItem] = []

        if let size = try directorySize(at: url) {
            result.append(
                DiskItem(
                    url: url,
                    name: url.lastPathComponent,
                    parentLabel: parentLabel(for: url),
                    size: size
                )
            )
        }

        if depth < Self.maxDepth {
            for child in try directories(in: url) {
                result.append(contentsOf: try collect(at: child, depth: depth + 1))
            }
        }
        return result
    }

    private func directories(in url: URL) throws -> [URL] {
        try directoryContents(at: url).filter { child in
            guard !isNestedMountPoint(child) else { return false }
            do {
                return try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            } catch let error as DiskScannerError {
                throw error
            } catch {
                if Self.isAccessDenied(error) {
                    throw DiskScannerError.accessRequired(child)
                }
                return false
            }
        }
    }

    private func directoryContents(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw DiskScannerError.accessRequired(url)
        }

        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            if Self.isAccessDenied(error) {
                throw DiskScannerError.accessRequired(url)
            }
            return []
        }
    }

    /// Sums allocated bytes recursively and reports denied paths to the caller.
    private func directorySize(at url: URL) throws -> Int64? {
        let keys: [URLResourceKey] = [.totalFileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey]
        var deniedURL: URL?
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { failedURL, error in
                if Self.isAccessDenied(error) {
                    deniedURL = failedURL
                    return false
                }
                return true
            }
        )

        if let deniedURL {
            throw DiskScannerError.accessRequired(deniedURL)
        }
        guard let enumerator else {
            if !fileManager.isReadableFile(atPath: url.path) {
                throw DiskScannerError.accessRequired(url)
            }
            return nil
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if isNestedMountPoint(fileURL) {
                enumerator.skipDescendants()
                continue
            }

            do {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                guard values.isRegularFile == true else { continue }
                total += Int64(values.totalFileAllocatedSize ?? values.totalFileSize ?? 0)
            } catch {
                if Self.isAccessDenied(error) {
                    throw DiskScannerError.accessRequired(fileURL.deletingLastPathComponent())
                }
            }
        }

        if let deniedURL {
            throw DiskScannerError.accessRequired(deniedURL)
        }
        return total
    }

    nonisolated private static func isAccessDenied(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError {
            return true
        }
        return error.domain == NSPOSIXErrorDomain && (error.code == EACCES || error.code == EPERM)
    }

    private func isNestedMountPoint(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path != rootURL.standardizedFileURL.path && mountedVolumePaths.contains(path)
    }

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
