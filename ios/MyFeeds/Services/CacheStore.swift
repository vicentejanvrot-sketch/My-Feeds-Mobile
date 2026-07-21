import Foundation
import SwiftData
import Observation

/// Manages the local SwiftData cache used to display the last synced feed data
/// when the device is offline. The cache mirrors a subset of the Supabase tables
/// (agents, channels, runs, items) needed to render the Dashboard, Feed, History,
/// Agents, and Agent Detail screens without a network connection.
///
/// The flow is:
/// 1. On app launch, `loadCachedSnapshot()` returns the last persisted data so the
///    UI can render immediately.
/// 2. Each screen's `load()` calls `syncAll()` (or a targeted `sync*` method) which
///    fetches fresh data from Supabase and writes it into the cache.
/// 3. When a fetch fails (offline), the screen falls back to the cached snapshot.
@Observable
final class CacheStore {
    static let shared = CacheStore()

    let container: ModelContainer

    /// Timestamp of the most recent successful sync across any table.
    var lastSyncedAt: Date?

    private init() {
        do {
            let schema = Schema([
                CachedFeedItem.self,
                CachedAgent.self,
                CachedChannel.self,
                CachedRun.self
            ])
            let config = ModelConfiguration(
                "MyFeedsCache",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If the on-disk store is unreadable (schema migration, corruption),
            // fall back to an in-memory container so the app still launches.
            let schema = Schema([
                CachedFeedItem.self,
                CachedAgent.self,
                CachedChannel.self,
                CachedRun.self
            ])
            let config = ModelConfiguration(
                "MyFeedsCache",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: false
            )
            // try! is safe here because in-memory containers don't touch disk.
            container = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    // MARK: - Read

    /// Returns the cached feed items ordered newest-first by `publishedAt`.
    func cachedFeedItems(limit: Int = 500) -> [FeedItem] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedFeedItem>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row -> FeedItem in
            var item = FeedItem(
                id: row.id,
                agentId: row.agentId,
                runId: row.runId,
                videoId: row.videoId,
                url: row.url,
                title: row.title,
                thumbnailUrl: row.thumbnailUrl,
                channelName: row.channelName,
                channelId: row.channelId,
                publishedAt: row.publishedAt,
                userStatus: row.userStatus.flatMap(ItemStatus.init(rawValue:)),
                itemAnalysis: nil
            )
            // Rebuild a single-row item_analysis from the flattened columns.
            if row.analysisDurationSeconds != nil || row.analysisViews != nil
                || row.analysisShortSummary != nil || row.analysisRankingScore != nil {
                let tags = row.analysisTagsJoined?
                    .split(separator: "\u{1F}")
                    .map(String.init)
                let analysis = ItemAnalysis(
                    id: UUID().uuidString,
                    itemId: row.id,
                    durationSeconds: row.analysisDurationSeconds,
                    definition: nil,
                    viewsAtAnalysis: row.analysisViews,
                    likesAtAnalysis: row.analysisLikes,
                    commentsAtAnalysis: row.analysisComments,
                    analyzedAt: nil,
                    shortSummary: row.analysisShortSummary,
                    keyPoints: nil,
                    tags: tags,
                    rankingScore: row.analysisRankingScore
                )
                item.itemAnalysis = [analysis]
            }
            return item
        }
    }

    /// Returns cached agents, sorted alphabetically by name (matches the UI sort).
    func cachedAgents() -> [Agent] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedAgent>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row in
            Agent(
                id: row.id,
                userId: row.userId,
                name: row.name,
                description: row.agentDescription,
                scheduleFrequency: row.scheduleFrequency,
                runTimeLocal: row.runTimeLocal,
                timezone: row.timezone,
                lookbackHours: row.lookbackHours,
                includeShorts: row.includeShorts,
                includeLive: row.includeLive,
                minDurationMinutes: row.minDurationMinutes,
                aiProvider: row.aiProvider,
                freshnessWeight: row.freshnessWeight,
                priorityWeight: row.priorityWeight,
                durationWeight: row.durationWeight,
                keywordWeight: row.keywordWeight,
                keywords: row.keywordsJoined?
                    .split(separator: "\u{1F}")
                    .map(String.init),
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    /// Returns cached channels for a specific agent, ordered by priority desc.
    func cachedChannels(agentId: String) -> [Channel] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedChannel>(
            predicate: #Predicate { $0.agentId == agentId },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row in
            Channel(
                id: row.id,
                agentId: row.agentId,
                channelUrl: row.channelUrl,
                channelId: row.channelId,
                uploadsPlaylistId: row.uploadsPlaylistId,
                channelName: row.channelName,
                channelThumbnail: row.channelThumbnail,
                priority: row.priority,
                isEnabled: row.isEnabled,
                userStatus: row.userStatus.flatMap(ItemStatus.init(rawValue:)),
                lastScannedAt: row.lastScannedAt,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    /// Returns all cached channels.
    func cachedAllChannels() -> [Channel] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedChannel>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row in
            Channel(
                id: row.id,
                agentId: row.agentId,
                channelUrl: row.channelUrl,
                channelId: row.channelId,
                uploadsPlaylistId: row.uploadsPlaylistId,
                channelName: row.channelName,
                channelThumbnail: row.channelThumbnail,
                priority: row.priority,
                isEnabled: row.isEnabled,
                userStatus: row.userStatus.flatMap(ItemStatus.init(rawValue:)),
                lastScannedAt: row.lastScannedAt,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    /// Returns cached runs, newest first.
    func cachedRuns(limit: Int = 50) -> [Run] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedRun>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row in
            Run(
                id: row.id,
                agentId: row.agentId,
                startedAt: row.startedAt,
                finishedAt: row.finishedAt,
                status: row.status,
                videosFoundCount: row.videosFoundCount,
                videosNewCount: row.videosNewCount,
                videosEnrichedCount: row.videosEnrichedCount,
                errorSummary: row.errorSummary,
                channelsTotal: row.channelsTotal,
                channelsScanned: row.channelsScanned,
                currentChannelName: row.currentChannelName
            )
        }
    }

    /// Returns cached runs for a specific agent, newest first.
    func cachedAgentRuns(agentId: String, limit: Int = 30) -> [Run] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedRun>(
            predicate: #Predicate { $0.agentId == agentId },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.map { row in
            Run(
                id: row.id,
                agentId: row.agentId,
                startedAt: row.startedAt,
                finishedAt: row.finishedAt,
                status: row.status,
                videosFoundCount: row.videosFoundCount,
                videosNewCount: row.videosNewCount,
                videosEnrichedCount: row.videosEnrichedCount,
                errorSummary: row.errorSummary,
                channelsTotal: row.channelsTotal,
                channelsScanned: row.channelsScanned,
                currentChannelName: row.currentChannelName
            )
        }
    }

    // MARK: - Sync (write)

    /// Replaces the entire cache with the given snapshot. Called after a successful
    /// Supabase fetch so the cache always reflects the last successful sync.
    func replaceAll(
        agents: [Agent] = [],
        channels: [Channel] = [],
        runs: [Run] = [],
        feedItems: [FeedItem] = []
    ) {
        let context = ModelContext(container)
        let now = Date()

        // Agents
        if !agents.isEmpty {
            try? context.delete(model: CachedAgent.self)
            for agent in agents {
                context.insert(CachedAgent(
                    id: agent.id,
                    name: agent.name,
                    userId: agent.userId,
                    agentDescription: agent.description,
                    scheduleFrequency: agent.scheduleFrequency,
                    runTimeLocal: agent.runTimeLocal,
                    timezone: agent.timezone,
                    lookbackHours: agent.lookbackHours,
                    includeShorts: agent.includeShorts,
                    includeLive: agent.includeLive,
                    minDurationMinutes: agent.minDurationMinutes,
                    aiProvider: agent.aiProvider,
                    freshnessWeight: agent.freshnessWeight,
                    priorityWeight: agent.priorityWeight,
                    durationWeight: agent.durationWeight,
                    keywordWeight: agent.keywordWeight,
                    keywordsJoined: agent.keywords?.joined(separator: "\u{1F}"),
                    lastSyncedAt: now
                ))
            }
        }

        // Channels
        if !channels.isEmpty {
            try? context.delete(model: CachedChannel.self)
            for channel in channels {
                context.insert(CachedChannel(
                    id: channel.id,
                    agentId: channel.agentId,
                    channelUrl: channel.channelUrl,
                    channelId: channel.channelId,
                    uploadsPlaylistId: channel.uploadsPlaylistId,
                    channelName: channel.channelName,
                    channelThumbnail: channel.channelThumbnail,
                    priority: channel.priority,
                    isEnabled: channel.isEnabled,
                    userStatus: channel.userStatus?.rawValue,
                    lastScannedAt: channel.lastScannedAt,
                    lastSyncedAt: now
                ))
            }
        }

        // Runs
        if !runs.isEmpty {
            try? context.delete(model: CachedRun.self)
            for run in runs {
                context.insert(CachedRun(
                    id: run.id,
                    agentId: run.agentId,
                    startedAt: run.startedAt,
                    finishedAt: run.finishedAt,
                    status: run.status,
                    videosFoundCount: run.videosFoundCount,
                    videosNewCount: run.videosNewCount,
                    videosEnrichedCount: run.videosEnrichedCount,
                    errorSummary: run.errorSummary,
                    channelsTotal: run.channelsTotal,
                    channelsScanned: run.channelsScanned,
                    currentChannelName: run.currentChannelName,
                    lastSyncedAt: now
                ))
            }
        }

        // Feed items
        if !feedItems.isEmpty {
            try? context.delete(model: CachedFeedItem.self)
            for item in feedItems {
                let analysis = item.analysis
                context.insert(CachedFeedItem(
                    id: item.id,
                    agentId: item.agentId,
                    runId: item.runId,
                    videoId: item.videoId,
                    url: item.url,
                    title: item.title,
                    thumbnailUrl: item.thumbnailUrl,
                    channelName: item.channelName,
                    channelId: item.channelId,
                    publishedAt: item.publishedAt,
                    userStatus: item.userStatus?.rawValue,
                    analysisDurationSeconds: analysis?.durationSeconds,
                    analysisViews: analysis?.viewsAtAnalysis,
                    analysisLikes: analysis?.likesAtAnalysis,
                    analysisComments: analysis?.commentsAtAnalysis,
                    analysisShortSummary: analysis?.shortSummary,
                    analysisRankingScore: analysis?.rankingScore,
                    analysisTagsJoined: analysis?.tags?.joined(separator: "\u{1F}"),
                    lastSyncedAt: now
                ))
            }
        }

        do {
            try context.save()
            lastSyncedAt = now
        } catch {
            // A failed save doesn't crash the app; we'll retry on the next sync.
        }
    }

    /// Updates the cached feed item's user status (called after a successful status
    /// mutation so the cache stays consistent with the server).
    func updateFeedItemStatus(id: String, status: ItemStatus) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedFeedItem>(
            predicate: #Predicate { $0.id == id }
        )
        guard let row = try? context.fetch(descriptor).first else { return }
        row.userStatus = status.rawValue
        row.lastSyncedAt = Date()
        try? context.save()
    }

    /// Bulk-updates cached feed item statuses (mirrors the server bulk mutation).
    func bulkUpdateFeedItemStatus(ids: [String], status: ItemStatus) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedFeedItem>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        guard let rows = try? context.fetch(descriptor) else { return }
        let now = Date()
        for row in rows {
            row.userStatus = status.rawValue
            row.lastSyncedAt = now
        }
        try? context.save()
    }

    // MARK: - Offline helpers

    /// `true` when the device currently has no network connection. Used by views
    /// to decide whether to show an "offline — showing last synced data" banner.
    var isOnline: Bool {
        // A lightweight reachability check using a dummy URL request. We don't
        // import SystemConfiguration to keep the dependency surface small; the
        // Supabase fetches themselves are the source of truth for "can we reach
        // the server", and this is just a UI hint.
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else {
            return true
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.httpMethod = "HEAD"
        var semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let response = response as? HTTPURLResponse, response.statusCode > 0 {
                reachable = true
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 2.5)
        return reachable
    }
}
