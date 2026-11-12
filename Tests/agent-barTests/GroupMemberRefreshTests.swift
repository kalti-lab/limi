import Foundation
import Testing
@testable import agent_bar

// The accounts a group holds beyond its menu bar lines are refreshed too: each service is asked about one account at a
// time, the menu bar's accounts first, resting between requests when the store is told to.
@MainActor
struct GroupMemberRefreshTests {
    @Test func membersWithoutLinesAreLoaded() async throws {
        let f = try RefreshFixture(claude: 3, codex: 1); defer { f.close() }
        let (a, c, outside, b) = (f.claude[0], f.claude[1], f.claude[2], f.codex[0])
        f.store.updateDisplay { $0.layouts = [MenuBarLayout(name: "Work", rows: [line(a, slot: 0)], memberIDs: [a.id, b.id, c.id])] }
        await f.store.refresh()
        for member in [a, b, c] { #expect(await f.loader.count(member.id) == 1) }
        #expect(await f.loader.count(outside.id) == 0)
        #expect(f.store.snapshot(for: c).weekly?.utilization != nil)
    }

    @Test func oneRequestPerServiceAtATime() async throws {
        let f = try RefreshFixture(claude: 4, codex: 3, answerAfter: .milliseconds(20)); defer { f.close() }
        f.store.updateDisplay { $0.layouts = [MenuBarLayout(name: "All", rows: [line(f.claude[0], slot: 0)], memberIDs: f.accounts.map(\.id))] }
        // While the first Claude request is under way, no other Claude request starts, and Codex is asked side by side.
        await f.loader.hold(f.claude[0].id)
        let round = Task { await f.store.refresh() }
        try await f.waitFor { await f.loader.order(.codex).count == 3 }
        #expect(await f.loader.order(.claude) == [f.claude[0].id])
        await f.loader.release(f.claude[0].id)
        await round.value
        #expect(await f.loader.requests.count == 7)
        #expect(await f.loader.mostAtOnce == [.claude: 1, .codex: 1])
    }

    @Test func requestsOfAServiceAreSpaced() async throws {
        let f = try RefreshFixture(claude: 3, codex: 2, spacing: [.claude: .milliseconds(80)]); defer { f.close() }
        f.store.updateDisplay { $0.layouts = [MenuBarLayout(name: "All", rows: [line(f.claude[0], slot: 0)], memberIDs: f.accounts.map(\.id))] }
        await f.store.refresh()
        let starts = await f.loader.starts(.claude)
        #expect(starts.count == 3)
        for (earlier, later) in zip(starts, starts.dropFirst()) { #expect(earlier.duration(to: later) >= .milliseconds(80)) }
        #expect(await f.loader.starts(.codex).count == 2)
        // Only the app rests: 1 s between Claude requests and 0.5 s between Codex ones. A store given nothing does not.
        #expect(UsageStore.appRequestSpacing == [.claude: .seconds(1), .codex: .milliseconds(500)])
        let plain = try RefreshFixture(claude: 1); defer { plain.close() }
        #expect(plain.store.requestSpacing.isEmpty)
    }

    @Test func lineAccountsLoadFirst() async throws {
        let f = try RefreshFixture(claude: 3, codex: 2); defer { f.close() }
        let (c1, c2, c3, x1, x2) = (f.claude[0], f.claude[1], f.claude[2], f.codex[0], f.codex[1])
        let shown = MenuBarLayout(name: "Shown", rows: [line(c3, slot: 0), line(x2, slot: 1)], memberIDs: [c1.id, c2.id, c3.id, x1.id, x2.id])
        // A line of a group the menu bar does not show does not count.
        let off = MenuBarLayout(name: "Off", enabled: false, rows: [line(c1, slot: 0)])
        f.store.updateDisplay { $0.layouts = [shown, off] }
        // What the timer calls.
        f.store.refreshOnSchedule()
        try await f.waitFor { !f.store.isRefreshing }
        #expect(await f.loader.order(.claude) == [c3.id, c1.id, c2.id])
        #expect(await f.loader.order(.codex) == [x2.id, x1.id])
    }

    @Test func removingAMemberStopsItsRefresh() async throws {
        let f = try RefreshFixture(claude: 2); defer { f.close() }
        let (a, b) = (f.claude[0], f.claude[1])
        let group = MenuBarLayout(name: "Work", rows: [line(a, slot: 0)], memberIDs: [a.id, b.id])
        f.store.updateDisplay { $0.layouts = [group] }

        // Leaving while its request is under way cancels the request, and the answer is not used.
        await f.loader.hold(b.id)
        let round = Task { await f.store.refresh() }
        try await f.waitFor { await f.loader.count(b.id) == 1 }
        f.store.removeGroupMember(b.id, from: group.id)
        #expect(await f.loader.wasCancelled(b.id))
        await f.loader.release(b.id)
        await round.value
        #expect(f.store.snapshots[b.id] == nil)

        // Back in the group it is read again. Leaving once more pauses it with the usage it had.
        f.store.addGroupMember(b.id, to: group.id)
        await f.store.refresh()
        #expect(await f.loader.count(b.id) == 2)
        f.store.removeGroupMember(b.id, from: group.id)
        #expect(f.store.snapshot(for: b).note == "Hidden account. Refresh is paused.")
        await f.store.refresh()
        #expect(await f.loader.count(b.id) == 2)
        f.store.addGroupMember(b.id, to: group.id)
        #expect(f.store.snapshot(for: b).note == "Cached usage. Waiting for the next refresh.")
    }
}

/// A line that already carries its badge, so reading a file does not change it.
private func line(_ account: UsageAccount, slot: Int) -> MenuBarLine {
    MenuBarLine(accountID: account.id, metricID: "weekly", slot: slot, badgeText: account.name)
}

@MainActor
private final class RefreshFixture {
    let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("member-refresh-\(UUID())"))
    let suite = "member-refresh-\(UUID())"
    let defaults: UserDefaults
    let claude: [UsageAccount]
    let codex: [UsageAccount]
    var accounts: [UsageAccount] { claude + codex }
    let loader: RefreshLoader
    let store: UsageStore

    init(claude claudeCount: Int, codex codexCount: Int = 0, spacing: [ProviderKind: Duration] = [:],
         answerAfter: Duration = .zero) throws {
        defaults = UserDefaults(suiteName: suite)!
        claude = (0..<claudeCount).map { UsageAccount(id: UUID(), provider: .claude, name: "Claude \($0 + 1)", credentialID: UUID()) }
        codex = (0..<codexCount).map { UsageAccount(id: UUID(), provider: .codex, name: "Codex \($0 + 1)", credentialID: UUID()) }
        let loader = RefreshLoader(answerAfter: answerAfter)
        self.loader = loader
        var registry = AccountRegistry(accounts: claude + codex); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        try files.write(DisplayConfiguration.initial(registry), to: files.root.appendingPathComponent("display-v2.json"))
        store = UsageStore(settings: AppSettings(defaults: defaults), files: files, autoRefresh: false,
                           loadAccount: { await loader.load($0, control: $1) }, requestSpacing: spacing)
    }
    func close() { store.shutdown(); try? FileManager.default.removeItem(at: files.root); defaults.removePersistentDomain(forName: suite) }
    func waitFor(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !(await condition()) {
            if Date() > deadline { throw AccountError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// Answers at once, after `answerAfter`, or once a held account is released, and records who was asked when and how many
/// requests were under way at once.
private actor RefreshLoader {
    struct Request: Sendable { let id: UUID; let provider: ProviderKind; let start: ContinuousClock.Instant }
    private(set) var requests: [Request] = []
    private(set) var mostAtOnce: [ProviderKind: Int] = [:]
    private var running: [ProviderKind: Int] = [:]
    private var held: Set<UUID> = []
    private var controls: [UUID: OperationControl] = [:]
    private let answerAfter: Duration
    init(answerAfter: Duration) { self.answerAfter = answerAfter }

    func count(_ id: UUID) -> Int { requests.filter { $0.id == id }.count }
    func order(_ provider: ProviderKind) -> [UUID] { requests.filter { $0.provider == provider }.map(\.id) }
    func starts(_ provider: ProviderKind) -> [ContinuousClock.Instant] { requests.filter { $0.provider == provider }.map(\.start) }
    func wasCancelled(_ id: UUID) -> Bool { controls[id]?.cancelled == true }
    func hold(_ id: UUID) { held.insert(id) }
    func release(_ id: UUID) { held.remove(id) }

    func load(_ account: UsageAccount, control: OperationControl) async -> ProviderSnapshot {
        requests.append(Request(id: account.id, provider: account.provider, start: ContinuousClock.now))
        controls[account.id] = control
        running[account.provider, default: 0] += 1
        mostAtOnce[account.provider] = max(mostAtOnce[account.provider] ?? 0, running[account.provider] ?? 0)
        if answerAfter > .zero { try? await Task.sleep(for: answerAfter) }
        let deadline = Date().addingTimeInterval(10)
        while held.contains(account.id) && Date() < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        running[account.provider, default: 1] -= 1
        return ProviderSnapshot(provider: account.provider, updatedAt: .now, fiveHour: nil,
            weekly: WindowSummary(tokens: 42, limitTokens: 100, resetAt: nil, displayStyle: .percentage),
            modelWeeklies: [], planName: nil, sourceDescription: "Fixture", note: nil, isStale: false, requiresLogin: false)
    }
}
