import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var claudeSnapshot = ProviderSnapshot.placeholder(for: .claude)
    @Published private(set) var codexSnapshot = ProviderSnapshot.placeholder(for: .codex)
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false

    private let settings: AppSettings
    private let availableProviders: Set<ProviderKind>
    private let claudeProvider = ClaudeUsageProvider()
    private let codexProvider = CodexUsageProvider()

    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings, availableProviders: [ProviderKind]) {
        self.settings = settings
        self.availableProviders = Set(availableProviders)
        bindSettings()
        configureTimer()
        refreshNow()
    }

    func snapshot(for provider: ProviderKind) -> ProviderSnapshot {
        switch provider {
        case .claude:
            return claudeSnapshot
        case .codex:
            return codexSnapshot
        }
    }

    func refreshNow() {
        guard refreshTask == nil else { return }

        isRefreshing = true
        refreshTask = Task { [weak self] in
            guard let self else { return }

            var nextClaudeSnapshot = self.claudeSnapshot
            var nextCodexSnapshot = self.codexSnapshot

            if availableProviders.contains(.claude) {
                let fetched = await claudeProvider.load()
                nextClaudeSnapshot = Self.merge(fetched: fetched, into: nextClaudeSnapshot)
            }

            if availableProviders.contains(.codex) {
                let fetched = await codexProvider.load()
                nextCodexSnapshot = Self.merge(fetched: fetched, into: nextCodexSnapshot)
            }

            guard Task.isCancelled == false else { return }

            self.claudeSnapshot = nextClaudeSnapshot
            self.codexSnapshot = nextCodexSnapshot
            self.lastRefresh = .now
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    private static func merge(fetched: ProviderSnapshot, into previous: ProviderSnapshot) -> ProviderSnapshot {
        guard fetched.isStale, !previous.isStale else {
            return fetched
        }
        return ProviderSnapshot(
            provider: previous.provider,
            updatedAt: previous.updatedAt,
            fiveHour: previous.fiveHour,
            weekly: previous.weekly,
            planName: previous.planName,
            todayTokens: fetched.todayTokens,
            monthTokens: fetched.monthTokens,
            recentSessions: fetched.recentSessions,
            modelBreakdown: fetched.modelBreakdown,
            sourceDescription: previous.sourceDescription,
            note: fetched.note,
            isStale: true
        )
    }

    private func bindSettings() {
        settings.$refreshIntervalSeconds
            .dropFirst()
            .sink { [weak self] _ in
                self?.configureTimer()
            }
            .store(in: &cancellables)
    }

    private func configureTimer() {
        refreshTimer?.invalidate()
        let interval = max(settings.refreshIntervalSeconds, 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
    }
}
