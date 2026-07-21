import Foundation
import SwiftData

/// Snapshot of a feed item row, persisted for offline access.
///
/// Stores only the columns the UI needs to render a feed card. The `lastSyncedAt`
/// timestamp lets the cache decide whether to show a stale-data banner.
@Model
final class CachedFeedItem {
    @Attribute(.unique) var id: String
    var agentId: String?
    var runId: String?
    var videoId: String?
    var url: String?
    var title: String?
    var thumbnailUrl: String?
    var channelName: String?
    var channelId: String?
    var publishedAt: String?
    var userStatus: String?
    // Analysis (flattened — one row per item)
    var analysisDurationSeconds: Int?
    var analysisViews: Int?
    var analysisLikes: Int?
    var analysisComments: Int?
    var analysisShortSummary: String?
    var analysisRankingScore: Double?
    // Tags stored as a single comma-joined string (SwiftData can't store [String] directly).
    var analysisTagsJoined: String?
    var lastSyncedAt: Date

    init(
        id: String,
        agentId: String?,
        runId: String?,
        videoId: String?,
        url: String?,
        title: String?,
        thumbnailUrl: String?,
        channelName: String?,
        channelId: String?,
        publishedAt: String?,
        userStatus: String?,
        analysisDurationSeconds: Int?,
        analysisViews: Int?,
        analysisLikes: Int?,
        analysisComments: Int?,
        analysisShortSummary: String?,
        analysisRankingScore: Double?,
        analysisTagsJoined: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.agentId = agentId
        self.runId = runId
        self.videoId = videoId
        self.url = url
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.channelName = channelName
        self.channelId = channelId
        self.publishedAt = publishedAt
        self.userStatus = userStatus
        self.analysisDurationSeconds = analysisDurationSeconds
        self.analysisViews = analysisViews
        self.analysisLikes = analysisLikes
        self.analysisComments = analysisComments
        self.analysisShortSummary = analysisShortSummary
        self.analysisRankingScore = analysisRankingScore
        self.analysisTagsJoined = analysisTagsJoined
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Snapshot of an agent row, persisted for offline access.
@Model
final class CachedAgent {
    @Attribute(.unique) var id: String
    var name: String
    var userId: String?
    var agentDescription: String?
    var scheduleFrequency: String?
    var runTimeLocal: String?
    var timezone: String?
    var lookbackHours: Int?
    var includeShorts: Bool?
    var includeLive: Bool?
    var minDurationMinutes: Int?
    var aiProvider: String?
    var freshnessWeight: Double?
    var priorityWeight: Double?
    var durationWeight: Double?
    var keywordWeight: Double?
    var keywordsJoined: String?
    var lastSyncedAt: Date

    init(
        id: String,
        name: String,
        userId: String?,
        agentDescription: String?,
        scheduleFrequency: String?,
        runTimeLocal: String?,
        timezone: String?,
        lookbackHours: Int?,
        includeShorts: Bool?,
        includeLive: Bool?,
        minDurationMinutes: Int?,
        aiProvider: String?,
        freshnessWeight: Double?,
        priorityWeight: Double?,
        durationWeight: Double?,
        keywordWeight: Double?,
        keywordsJoined: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.name = name
        self.userId = userId
        self.agentDescription = agentDescription
        self.scheduleFrequency = scheduleFrequency
        self.runTimeLocal = runTimeLocal
        self.timezone = timezone
        self.lookbackHours = lookbackHours
        self.includeShorts = includeShorts
        self.includeLive = includeLive
        self.minDurationMinutes = minDurationMinutes
        self.aiProvider = aiProvider
        self.freshnessWeight = freshnessWeight
        self.priorityWeight = priorityWeight
        self.durationWeight = durationWeight
        self.keywordWeight = keywordWeight
        self.keywordsJoined = keywordsJoined
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Snapshot of a channel row, persisted for offline access.
@Model
final class CachedChannel {
    @Attribute(.unique) var id: String
    var agentId: String
    var channelUrl: String?
    var channelId: String?
    var uploadsPlaylistId: String?
    var channelName: String?
    var channelThumbnail: String?
    var priority: Int?
    var isEnabled: Bool?
    var userStatus: String?
    var lastScannedAt: String?
    var lastSyncedAt: Date

    init(
        id: String,
        agentId: String,
        channelUrl: String?,
        channelId: String?,
        uploadsPlaylistId: String?,
        channelName: String?,
        channelThumbnail: String?,
        priority: Int?,
        isEnabled: Bool?,
        userStatus: String?,
        lastScannedAt: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.agentId = agentId
        self.channelUrl = channelUrl
        self.channelId = channelId
        self.uploadsPlaylistId = uploadsPlaylistId
        self.channelName = channelName
        self.channelThumbnail = channelThumbnail
        self.priority = priority
        self.isEnabled = isEnabled
        self.userStatus = userStatus
        self.lastScannedAt = lastScannedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Snapshot of a run row, persisted for offline access.
@Model
final class CachedRun {
    @Attribute(.unique) var id: String
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
    var lastSyncedAt: Date

    init(
        id: String,
        agentId: String,
        startedAt: String?,
        finishedAt: String?,
        status: String,
        videosFoundCount: Int?,
        videosNewCount: Int?,
        videosEnrichedCount: Int?,
        errorSummary: String?,
        channelsTotal: Int?,
        channelsScanned: Int?,
        currentChannelName: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.agentId = agentId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.videosFoundCount = videosFoundCount
        self.videosNewCount = videosNewCount
        self.videosEnrichedCount = videosEnrichedCount
        self.errorSummary = errorSummary
        self.channelsTotal = channelsTotal
        self.channelsScanned = channelsScanned
        self.currentChannelName = currentChannelName
        self.lastSyncedAt = lastSyncedAt
    }
}
