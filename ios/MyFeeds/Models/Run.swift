import Foundation

/// Row in the shared `runs` table.
nonisolated struct Run: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String
    var startedAt: String?
    var finishedAt: String?
    var status: String
    var videosFoundCount: Int?
    var videosNewCount: Int?
    var videosEnrichedCount: Int?
    var errorSummary: String?
    var channelsTotal: Int?
    var channelsScanned: Int?
    var currentChannelName: String?

    var runStatus: RunStatus { RunStatus(rawValue: status) ?? .cancelled }
}
