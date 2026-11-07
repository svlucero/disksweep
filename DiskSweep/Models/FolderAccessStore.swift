import Foundation

/// Persists one-month, app-scoped security grants for mounted volumes.
struct FolderAccessStore {
    private struct Grant: Codable {
        var bookmarkData: Data
        let grantedAt: Date
    }

    private static let grantsKey = "authorizedVolumeGrants"
    private static let legacyBookmarkKey = "authorizedFolderBookmark"

    private let defaults: UserDefaults
    private let usesSecurityScope: Bool

    init(defaults: UserDefaults = .standard, usesSecurityScope: Bool = true) {
        self.defaults = defaults
        self.usesSecurityScope = usesSecurityScope

        // The previous bookmark format had no grant date, so it cannot be
        // safely treated as a current one-month authorization.
        defaults.removeObject(forKey: Self.legacyBookmarkKey)
    }

    /// Saves the user's grant for a volume and starts its one-month lifetime.
    func save(_ url: URL, forVolumeID volumeID: String, at grantedAt: Date = Date()) throws {
        let options: URL.BookmarkCreationOptions = usesSecurityScope ? [.withSecurityScope] : []
        let bookmarkData = try url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var grants = readGrants()
        grants[volumeID] = Grant(bookmarkData: bookmarkData, grantedAt: grantedAt)
        writeGrants(grants)
    }

    /// Resolves a grant if it is younger than one calendar month.
    func restore(
        forVolumeID volumeID: String,
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> URL? {
        var grants = readGrants()
        guard var grant = grants[volumeID] else { return nil }

        guard let expirationDate = calendar.date(byAdding: .month, value: 1, to: grant.grantedAt),
              now < expirationDate else {
            grants[volumeID] = nil
            writeGrants(grants)
            return nil
        }

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
                grants[volumeID] = grant
                writeGrants(grants)
            }
            return url
        } catch {
            grants[volumeID] = nil
            writeGrants(grants)
            return nil
        }
    }

    func clear(forVolumeID volumeID: String) {
        var grants = readGrants()
        grants[volumeID] = nil
        writeGrants(grants)
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
