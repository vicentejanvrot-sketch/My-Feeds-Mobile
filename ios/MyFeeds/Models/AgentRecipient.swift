import Foundation

/// Row in the shared `agent_recipients` table.
nonisolated struct AgentRecipient: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String
    var email: String
}
