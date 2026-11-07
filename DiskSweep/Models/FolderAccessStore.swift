import Foundation

/// Persists user-approved folder grants and their one-month expiration dates.
struct FolderAccessStore {
    private struct Grant: Codable {
        var bookmarkData: Data
        let grantedAt: Date
    }

    private static let grantsKey = "authorizedFolderGrants"
    private static let legacyVolumeGrantsKey = "authorizedVolumeGrants"
    private static let legacyBookmarkKey = "authorizedFolderBookmark"

    private let defaults: UserDefaults
    private let usesSecurityScope: Bool

    init(defaults: UserDefaults = .standard, usesSecurityScope: Bool = false) {
        self.defaults = defaults
        self.usesSecurityScope = usesSecurityScope

        // Previous local builds keyed grants by volume path, which is the same
        // path key used for folder grants when that grant covered a volume root.
        if defaults.data(forKey: Self.grantsKey) == nil,
           let oldGrants = defaults.data(forKey: Self.legacyVolumeGrantsKey) {
            defaults.set(oldGrants, forKey: Self.grantsKey)
        }
        defaults.removeObject(forKey: Self.legacyVolumeGrantsKey)

        // The original bookmark had no grant date and cannot safely be treated
        // as a current one-month authorization.
        defaults.removeObject(forKey: Self.legacyBookmarkKey)
    }

    /// Records explicit user approval for `url` and starts its one-month term.
    func save(_ url: URL, at grantedAt: Date = Date()) throws {
        let options: URL.BookmarkCreationOptions = usesSecurityScope ? [.withSecurityScope] : []
        let bookmarkData = try url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var grants = readGrants()
        grants[url.standardizedFileURL.path] = Grant(bookmarkData: bookmarkData, grantedAt: grantedAt)
        writeGrants(grants)
    }

    /// Resolves a non-expired grant for a folder path.
    func restore(
        forFolderURL url: URL,
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> URL? {
        restore(forPath: url.standardizedFileURL.path, at: now, calendar: calendar)
    }

    /// Resolves every currently valid grant, refreshing stale bookmarks without
    /// extending their original expiration date.
    func validFolderURLs(at now: Date = Date(), calendar: Calendar = .current) -> [URL] {
        let paths = Array(readGrants().keys)
        return paths.compactMap { restore(forPath: $0, at: now, calendar: calendar) }
    }

    /// Paths whose previous grant has expired. The scanner treats them as
    /// requiring renewed approval before attempting to read them.
    func expiredFolderPaths(at now: Date = Date(), calendar: Calendar = .current) -> Set<String> {
        readGrants().compactMap { path, grant in
            guard let expiresAt = calendar.date(byAdding: .month, value: 1, to: grant.grantedAt),
                  now >= expiresAt else { return nil }
            return path
        }.reduce(into: Set<String>()) { $0.insert($1) }
    }

    func clear(forFolderURL url: URL) {
        var grants = readGrants()
        grants[url.standardizedFileURL.path] = nil
        writeGrants(grants)
    }

    func clearAll() {
        defaults.removeObject(forKey: Self.grantsKey)
    }

    private func restore(forPath path: String, at now: Date, calendar: Calendar) -> URL? {
        var grants = readGrants()
        guard var grant = grants[path] else { return nil }

        guard let expiresAt = calendar.date(byAdding: .month, value: 1, to: grant.grantedAt),
              now < expiresAt else { return nil }

        do {
            var isStale = false
            let options: URL.BookmarkResolutionOptions = usesSecurityScope ? [.withSecurityScope] : []
            let url = try URL(
                resolvingBookmarkData: grant.bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                let creationOptions: URL.BookmarkCreationOptions = usesSecurityScope ? [.withSecurityScope] : []
                grant.bookmarkData = try url.bookmarkData(
                    options: creationOptions,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                grants[path] = grant
                writeGrants(grants)
            }
            return url
        } catch {
            grants[path] = nil
            writeGrants(grants)
            return nil
        }
    }

    private func readGrants() -> [String: Grant] {
        guard let data = defaults.data(forKey: Self.grantsKey),
              let grants = try? JSONDecoder().decode([String: Grant].self, from: data) else {
            return [:]
        }
        return grants
    }

    private func writeGrants(_ grants: [String: Grant]) {
        guard !grants.isEmpty else {
            defaults.removeObject(forKey: Self.grantsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(grants) else { return }
        defaults.set(data, forKey: Self.grantsKey)
    }
}
