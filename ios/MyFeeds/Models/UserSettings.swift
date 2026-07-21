import Foundation

/// Safe projection of `user_settings` (key columns are never selected).
nonisolated struct UserSettings: Codable, Hashable, Sendable {
    var userId: String
    var defaultEmail: String?
    var createdAt: String?
    var updatedAt: String?
}

/// Per-agent item counts computed via HEAD count queries.
nonisolated struct AgentItemCounts: Hashable, Sendable {
    var total = 0
    var watched = 0
    var unwatched = 0
    var watchLater = 0
    var liked = 0
}
