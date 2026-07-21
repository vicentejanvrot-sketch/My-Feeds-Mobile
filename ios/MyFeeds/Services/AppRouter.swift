import Foundation
import Observation

/// Video-player launch request (presented as a full-screen cover).
struct PlayerRequest: Identifiable, Equatable {
    let id = UUID()
    let videoId: String
    let itemId: String?
}

/// Cross-tab feed deep-link (from Dashboard feed cards).
struct FeedRequest: Equatable {
    let agentId: String?
    let status: ItemStatus?
}

enum AppTab: Hashable {
    case dashboard
    case agents
    case feed
    case history
    case settings
}

/// Global navigation coordinator shared across tabs.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var feedRequest: FeedRequest?
    var playerRequest: PlayerRequest?

    func openFeed(agentId: String?, status: ItemStatus?) {
        feedRequest = FeedRequest(agentId: agentId, status: status)
        selectedTab = .feed
    }

    func openVideo(videoId: String, itemId: String?) {
        playerRequest = PlayerRequest(videoId: videoId, itemId: itemId)
    }
}
