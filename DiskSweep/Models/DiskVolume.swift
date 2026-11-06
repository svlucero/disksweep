import Foundation

/// A mounted volume that can be scanned by the app.
struct DiskVolume: Identifiable, Hashable {
    let url: URL
    let name: String

    var id: String { url.standardizedFileURL.path }
    var label: String { "\(name) (\(url.path))" }

    /// Lists user-browsable mounted volumes, including local and removable volumes.
    static func mounted(using fileManager: FileManager = .default) -> [DiskVolume] {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsBrowsableKey]
        let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: []) ?? []
        let volumes = urls.compactMap { url -> DiskVolume? in
            let path = url.standardizedFileURL.path
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.volumeIsBrowsable == true else {
                return nil
            }
            let name = values.volumeName ?? url.lastPathComponent
            return DiskVolume(url: url, name: name.isEmpty ? path : name)
        }

        let uniqueVolumes = Dictionary(volumes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return uniqueVolumes.values.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
    }

    /// Finds the mounted volume containing `url`, preferring the most specific mount point.
    static func containing(_ url: URL, in volumes: [DiskVolume]) -> DiskVolume? {
        let path = url.standardizedFileURL.path
        if let identifier = (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier {
            let matchingVolumes = volumes.filter { volume in
                guard let mountedIdentifier = (try? volume.url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier else {
                    return false
                }
                return mountedIdentifier.isEqual(identifier)
            }
            if let pathMatch = matchingVolumes
                .filter({ volume in
                    let mountPath = volume.url.standardizedFileURL.path
                    return path == mountPath || path.hasPrefix(mountPath == "/" ? "/" : mountPath + "/")
                })
                .max(by: { $0.url.path.count < $1.url.path.count }) {
                return pathMatch
            }
            if let matchingVolume = matchingVolumes.first { return matchingVolume }
        }

        let pathMatch = volumes
            .filter { volume in
                let mountPath = volume.url.standardizedFileURL.path
                return path == mountPath || path.hasPrefix(mountPath == "/" ? "/" : mountPath + "/")
            }
            .max(by: { $0.url.path.count < $1.url.path.count })
        if let pathMatch {
            return pathMatch
        }
        return nil
    }
}
