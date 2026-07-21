import SwiftUI
import Observation

/// Global state + orchestration for the full-screen agent-run overlay.
/// Mirrors the companion apps: insert run row → show overlay → invoke
/// `run-agent` edge function → poll the run row every 1.5s until terminal.
@Observable
final class RunningOverlayStore {
    enum Phase: Equatable {
        case running
        case success(message: String)
        case error(message: String)
    }

    struct OverlayState: Equatable {
        var agentName: String
        var runId: String
        var phase: Phase
        var channelsTotal: Int = 0
        var channelsScanned: Int = 0
        var currentChannelName: String?
    }

    var state: OverlayState?
    /// Agent id currently running ("all" during Run All).
    var pendingId: String?
    /// Incremented after each finished run so screens can refetch.
    var runCompletionCounter = 0

    var isVisible: Bool { state != nil }

    func dismiss() {
        state = nil
    }

    /// Run a single agent end-to-end.
    func run(agent: Agent) async {
        guard pendingId == nil else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingId = agent.id
        defer {
            pendingId = nil
            runCompletionCounter += 1
        }
        await runInternal(agent: agent)
    }

    /// Run every agent sequentially; per-agent failures don't stop the loop.
    func runAll(agents: [Agent]) async {
        guard pendingId == nil, !agents.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingId = "all"
        defer {
            pendingId = nil
            runCompletionCounter += 1
        }
        for agent in agents {
            await runInternal(agent: agent)
        }
        state = nil
    }

    private func runInternal(agent: Agent) async {
        let service = SupabaseService.shared
        let run: Run
        do {
            run = try await service.startRun(agentId: agent.id)
        } catch {
            state = OverlayState(agentName: agent.name, runId: "", phase: .error(message: error.localizedDescription))
            await holdThenClearIfError(seconds: 4)
            return
        }

        state = OverlayState(agentName: agent.name, runId: run.id, phase: .running)

        do {
            try await service.invokeRunAgent(agentId: agent.id, runId: run.id)
        } catch {
            let message = extractEdgeErrorMessage(error)
            try? await service.markRunFailed(runId: run.id, message: message)
            state = OverlayState(agentName: agent.name, runId: run.id, phase: .error(message: message))
            await holdThenClearIfError(seconds: 4)
            return
        }

        // Poll for terminal status
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.5))
            guard let current = try? await service.fetchRun(id: run.id) else { continue }
            switch current.runStatus {
            case .running:
                if state?.runId == run.id {
                    state?.channelsTotal = current.channelsTotal ?? 0
                    state?.channelsScanned = current.channelsScanned ?? 0
                    state?.currentChannelName = current.currentChannelName
                }
            case .success:
                let count = current.videosNewCount ?? 0
                let message = count > 0 ? "Found \(count) new videos" : "No new videos found"
                state = OverlayState(agentName: agent.name, runId: run.id, phase: .success(message: message))
                try? await Task.sleep(for: .seconds(2.5))
                if case .success = state?.phase { state = nil }
                return
            case .partial:
                let count = current.videosNewCount ?? 0
                let message = count > 0
                    ? "Found \(count) new videos (some channels couldn't be scanned)"
                    : "Scan finished — some channels couldn't be scanned."
                state = OverlayState(agentName: agent.name, runId: run.id, phase: .success(message: message))
                try? await Task.sleep(for: .seconds(2.5))
                if case .success = state?.phase { state = nil }
                return
            case .failed, .cancelled:
                let message = current.errorSummary ?? "An unknown error occurred"
                state = OverlayState(agentName: agent.name, runId: run.id, phase: .error(message: message))
                await holdThenClearIfError(seconds: 4)
                return
            }
        }
    }

    private func holdThenClearIfError(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
        if case .error = state?.phase { state = nil }
    }

    private func extractEdgeErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        return message.isEmpty ? "Edge function failed" : message
    }
}

/// Full-screen overlay view shown during agent runs.
struct RunningOverlayView: View {
    @Environment(RunningOverlayStore.self) private var overlay
    @State private var pulse = false

    var body: some View {
        if let state = overlay.state {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.75))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    card(for: state)
                    if case .running = state.phase {
                        EmptyView()
                    } else {
                        Text("Tap anywhere to dismiss")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if case .running = state.phase { return }
                overlay.dismiss()
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func card(for state: RunningOverlayStore.OverlayState) -> some View {
        VStack(spacing: 16) {
            switch state.phase {
            case .running:
                ZStack {
                    Circle()
                        .stroke(.white.opacity(pulse ? 0 : 0.5), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulse ? 1.5 : 1)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
                Text("🚀 Running \"\(state.agentName)\"")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if state.channelsTotal > 0 {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Scanning channels")
                            Spacer()
                            Text("\(state.channelsScanned) / \(state.channelsTotal)")
                                .monospacedDigit()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.2))
                                Capsule().fill(.white)
                                    .frame(width: geo.size.width * progress(state))
                            }
                        }
                        .frame(height: 6)

                        if let channel = state.currentChannelName {
                            HStack(spacing: 6) {
                                Image(systemName: "tv")
                                    .font(.system(size: 12))
                                Text(channel)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                } else {
                    Text("Initializing…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }
            case .success(let message):
                ZStack {
                    Circle().fill(.white).frame(width: 64, height: 64)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hsl: 152, 69, 40))
                }
                Text("☑️ \"\(state.agentName)\" Completed!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            case .error(let message):
                Text("❌ \"\(state.agentName)\" Failed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
            }
        }
        .padding(24)
        .frame(maxWidth: 380)
        .background(cardColor(for: state.phase))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .white.opacity(0.15), radius: 24)
    }

    private func progress(_ state: RunningOverlayStore.OverlayState) -> CGFloat {
        guard state.channelsTotal > 0 else { return 0 }
        return CGFloat(state.channelsScanned) / CGFloat(state.channelsTotal)
    }

    private func cardColor(for phase: RunningOverlayStore.Phase) -> Color {
        switch phase {
        case .running: return Color(hsl: 199, 89, 48)
        case .success: return Color(hsl: 152, 69, 50)
        case .error: return Color(hsl: 0, 72, 55)
        }
    }
}
