import Foundation

/// Persists a user-selected folder as an app-scoped security bookmark.
struct FolderAccessStore {
    private let defaults: UserDefaults
    private let bookmarkKey: String
    private let usesSecurityScope: Bool

    init(
        defaults: UserDefaults = .standard,
        bookmarkKey: String = "authorizedFolderBookmark",
        usesSecurityScope: Bool = true
    ) {
        self.defaults = defaults
        self.bookmarkKey = bookmarkKey
        self.usesSecurityScope = usesSecurityScope
    }

    /// Saves access to `url` so it can be restored after the app relaunches.
    func save(_ url: URL) throws {
        let options: URL.BookmarkCreationOptions = usesSecurityScope ? [.withSecurityScope] : []
        let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
    }

    /// Resolves the saved folder and refreshes its bookmark if macOS marks it stale.
    func restore() -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }

        do {
            var isStale = false
            let options: URL.BookmarkResolutionOptions = usesSecurityScope ? [.withSecurityScope] : []
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale { try save(url) }
            return url
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
            return nil
        }
    }

    func clear() {
        defaults.removeObject(forKey: bookmarkKey)
    }
}
