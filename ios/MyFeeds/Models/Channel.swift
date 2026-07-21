import Foundation

/// Row in the shared `channels` table.
nonisolated struct Channel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String
    var channelUrl: String?
    var channelId: String?
    var uploadsPlaylistId: String?
    var channelName: String?
    var channelThumbnail: String?
    var priority: Int?
    var isEnabled: Bool?
    var userStatus: ItemStatus?
    var lastScannedAt: String?
    var createdAt: String?
    var updatedAt: String?

    var displayName: String {
        if let channelName, !channelName.isEmpty { return channelName }
        if let channelUrl, !channelUrl.isEmpty { return channelUrl }
        return "Unnamed"
    }
}
