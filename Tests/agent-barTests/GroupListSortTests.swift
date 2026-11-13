import Foundation
import Testing
@testable import agent_bar

// A group's list in Manual, Usage or Reset time order, by what each account's row shows, and each group remembering its own.
@MainActor
struct GroupListSortTests {
    @Test func eachSortOrdersTheRowsByWhatTheyShow() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let rows: [UUID: ProviderSnapshot] = [
            a: snapshot(fiveHour: window(30, resetsIn: 120), weekly: window(50, resetsIn: 4_320)),
            b: snapshot(fiveHour: window(80, resetsIn: 200), weekly: window(20, resetsIn: 4_000)),
            c: snapshot(.codex, fiveHour: window(10, resetsIn: 30), weekly: window(60, resetsIn: 5_000)),
            d: snapshot(weekly: window(95, resetsIn: 10_000)),
        ]
        let manual = [a, b, c, d]
        // Usage: each row's highest limit, highest first. Reset time: each row's soonest reset, soonest first.
        #expect(GroupListSort.usage.ordered(manual, now: now) { rows[$0] } == [d, b, c, a])
        #expect(GroupListSort.resetTime.ordered(manual, now: now) { rows[$0] } == [c, a, b, d])
        // Manual: the group's own order, whatever the rows show.
        #expect(GroupListSort.manual.ordered(manual, now: now) { rows[$0] } == manual)
        #expect(GroupListSort.manual.ordered([d, c, b, a], now: now) { rows[$0] } == [d, c, b, a])
    }

    @Test func aModelsWeeklyLimitCountsWhenItIsTheHighest() {
        let a = UUID(), b = UUID()
        // A's Fable week is both its highest limit and its soonest reset.
        let rows: [UUID: ProviderSnapshot] = [
            a: snapshot(fiveHour: window(40, resetsIn: 300), weekly: window(50, resetsIn: 6_000),
                        models: [ModelWeeklySummary(label: "Fable", window: window(97, resetsIn: 50))]),
            b: snapshot(fiveHour: window(90, resetsIn: 100), weekly: window(30, resetsIn: 7_000)),
        ]
        #expect(GroupListSort.highestPercent(rows[a]!) == 97)
        #expect(GroupListSort.usage.ordered([b, a], now: now) { rows[$0] } == [a, b])
        #expect(GroupListSort.resetTime.ordered([b, a], now: now) { rows[$0] } == [a, b])
        // Without it, A's highest is its week, below B's 5 hours, and B resets first.
        var plain = rows
        plain[a] = snapshot(fiveHour: window(40, resetsIn: 300), weekly: window(50, resetsIn: 6_000))
        #expect(GroupListSort.usage.ordered([b, a], now: now) { plain[$0] } == [b, a])
        #expect(GroupListSort.resetTime.ordered([b, a], now: now) { plain[$0] } == [b, a])
    }

    @Test func tiesKeepTheGroupsOrder() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        let rows: [UUID: ProviderSnapshot] = [
            // 44.9%, 45.1% and 45% all read 45%. Ten seconds after and before the hour read the same minute.
            a: snapshot(weekly: window(44.9, resetsIn: 60 + 10.0 / 60)),
            b: snapshot(weekly: window(45.1, resetsIn: 60 - 10.0 / 60)),
            c: snapshot(weekly: window(45, resetsIn: 59)),
            // Resets already past all read "Resets soon", however long ago.
            d: snapshot(weekly: window(46, resetsIn: -5)),
            e: snapshot(weekly: window(20, resetsIn: -90)),
        ]
        #expect(GroupListSort.usage.ordered([a, b, c, d, e], now: now) { rows[$0] } == [d, a, b, c, e])
        #expect(GroupListSort.resetTime.ordered([a, b, c, d, e], now: now) { rows[$0] } == [d, e, c, a, b])
        // The same rows in another order keep that order among the ties.
        #expect(GroupListSort.usage.ordered([c, b, a, e, d], now: now) { rows[$0] } == [d, c, b, a, e])
        #expect(GroupListSort.resetTime.ordered([c, b, a, e, d], now: now) { rows[$0] } == [e, d, c, b, a])
    }

    @Test func rowsWithNothingToReadGoLast() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
        let rows: [UUID: ProviderSnapshot] = [
            a: .placeholder(for: .claude), // Nothing read yet: "--".
            b: snapshot(weekly: window(20, resetsIn: 100)),
            c: ProviderSnapshot.placeholder(for: .codex).failed("Codex did not answer."), // Could not read: "--".
            // D has no row at all.
            e: snapshot(weekly: window(10)), // A value, without a reset time.
            f: snapshot(fiveHour: window(70, resetsIn: 400), stale: true), // Cached values still show, dimmed.
        ]
        #expect(GroupListSort.highestPercent(rows[a]!) == nil && GroupListSort.highestPercent(rows[c]!) == nil)
        #expect(GroupListSort.highestPercent(rows[e]!) == 10 && GroupListSort.soonestReset(rows[e]!, now: now) == nil)
        let manual = [a, b, c, d, e, f]
        #expect(GroupListSort.usage.ordered(manual, now: now) { rows[$0] } == [f, b, e, a, c, d])
        // With no reset time to go by, a row with values goes last too.
        #expect(GroupListSort.resetTime.ordered(manual, now: now) { rows[$0] } == [b, f, a, c, d, e])
    }

    // The sort reads the cells a row draws (`GroupAccountRow.cellMetrics`), and their percentages as the row writes them.
    @Test func theSortGoesByTheRowsOwnCells() {
        let antigravity = ProviderSnapshot(provider: .antigravity, updatedAt: now, fiveHour: window(20, resetsIn: 100),
            weekly: window(30, resetsIn: 2_000), modelWeeklies: [], planName: nil, sourceDescription: "Test", note: nil,
            isStale: false, requiresLogin: false, limitGroups: [
                LimitGroupSummary(label: "Gemini", fiveHour: window(20, resetsIn: 100), weekly: window(30, resetsIn: 2_000)),
                LimitGroupSummary(label: "Claude/GPT", fiveHour: window(85.4, resetsIn: 50), weekly: nil)])
        let snapshots = [
            snapshot(fiveHour: window(12, resetsIn: 30), weekly: window(64.6, resetsIn: 900),
                     models: [ModelWeeklySummary(label: "Opus", window: window(70, resetsIn: 800))]),
            snapshot(.codex, fiveHour: window(99.5), weekly: window(3, resetsIn: 20)),
            antigravity,
            .placeholder(for: .claude),
            ProviderSnapshot.placeholder(for: .codex).failed("Codex did not answer."),
        ]
        for snapshot in snapshots {
            let cells = GroupAccountRow.cellMetrics(snapshot).filter { $0.window != nil }
            #expect(DisplayMetric.reported(snapshot).map(\.id) == cells.map(\.id))
            let highest = cells.compactMap { $0.window?.utilization }.max()
            #expect(GroupListSort.highestPercent(snapshot).map { "\($0)%" } == highest.map { TokenFormatters.percentageString(for: $0) })
            // Every reset here is a whole number of minutes ahead, so it reads exactly as the cell has it.
            #expect(GroupListSort.soonestReset(snapshot, now: now) == cells.compactMap { $0.window?.resetAt }.min())
        }
        #expect(snapshots.map { GroupListSort.highestPercent($0) } == [70, 100, 85, nil, nil])
        let minutes: [Double?] = [30, 20, 50, nil, nil]
        #expect(snapshots.map { GroupListSort.soonestReset($0, now: now) } == minutes.map { $0.map { now.addingTimeInterval($0 * 60) } })
    }

    @Test func aGroupReadsAndSavesItsSort() throws {
        let account = UUID(), group = UUID()
        // A file from before groups had a sort reads as manual and saves without one.
        let old = try JSONDecoder().decode(DisplayConfiguration.self, from: file(account, group))
        let layout = try #require(old.layouts?.first)
        #expect(layout.listSort == nil && layout.effectiveListSort == .manual && old.valid)
        #expect(!String(decoding: try JSONEncoder().encode(old), as: UTF8.self).contains("listSort"))
        // Each choice reads back as it was saved.
        for sort in GroupListSort.allCases {
            var config = old
            config.layouts?[0].listSort = sort
            let read = try JSONDecoder().decode(DisplayConfiguration.self, from: JSONEncoder().encode(config))
            #expect(read.layouts == config.layouts && read.layouts?.first?.effectiveListSort == sort)
        }
        // One this version does not know, saved by a later version or broken, reads as manual; the rest of the file still reads.
        for value in ["\"name\"", "7", "null", "{}"] {
            let read = try JSONDecoder().decode(DisplayConfiguration.self, from: file(account, group, ",\"listSort\":\(value)"))
            #expect(read.layouts?.first?.effectiveListSort == .manual && read.layouts?.first?.name == "Work" && read.valid)
        }
    }

    @Test func eachGroupKeepsItsSortAcrossLaunches() throws {
        let f = try SortFixture(); defer { f.close() }
        let one = MenuBarLayout(name: "One", rows: [line(f.accounts[0], slot: 0)], memberIDs: [f.accounts[0].id, f.accounts[1].id])
        let two = MenuBarLayout(name: "Two", rows: [line(f.accounts[2], slot: 0)])
        f.store.updateDisplay { $0.layouts = [one, two] }
        #expect(f.store.listSort(for: one.id) == .manual && f.store.listSort(for: two.id) == .manual)
        #expect(f.store.listSort(for: UUID()) == nil)

        f.store.setListSort(.usage, for: one.id)
        f.store.setListSort(.resetTime, for: two.id)
        #expect(f.store.listSort(for: one.id) == .usage && f.store.listSort(for: two.id) == .resetTime)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        #expect(reopened.listSort(for: one.id) == .usage && reopened.listSort(for: two.id) == .resetTime)
        // Nothing else about the groups changed.
        #expect(reopened.displayConfiguration.layouts?.map(\.memberIDs) == [one.memberIDs, nil])
        #expect(reopened.displayConfiguration.layouts?.map(\.name) == ["One", "Two"])

        // Manual again is saved as no choice, as for a group that never chose.
        f.store.setListSort(.manual, for: one.id)
        #expect(f.store.displayConfiguration.layouts?.first?.listSort == nil)
        let again = f.reopened(); defer { again.shutdown() }
        #expect(again.listSort(for: one.id) == .manual && again.listSort(for: two.id) == .resetTime)
        // A group that does not exist changes nothing.
        let before = f.store.displayConfiguration
        f.store.setListSort(.usage, for: UUID())
        #expect(f.store.displayConfiguration == before)
    }

    @Test func groupsOfOlderSettingsStartManual() throws {
        let f = try SortFixture(); defer { f.close() }
        // Settings without groups saved: each account shows as its own group, in its own order.
        #expect(f.store.displayConfiguration.layouts == nil)
        let groups = f.store.displayConfiguration.effectiveLayouts
        #expect(!groups.isEmpty && groups.allSatisfy { f.store.listSort(for: $0.id) == .manual })
        // Choosing manual changes nothing, so the settings stay as they were.
        f.store.setListSort(.manual, for: groups[0].id)
        #expect(f.store.displayConfiguration.layouts == nil)
        // Another choice saves the groups, and that group alone remembers it.
        f.store.setListSort(.resetTime, for: groups[0].id)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        #expect(reopened.displayConfiguration.layouts?.map(\.id) == groups.map(\.id))
        #expect(groups.map { reopened.listSort(for: $0.id) } == [.resetTime] + Array(repeating: .manual, count: groups.count - 1))
    }

    @Test func thePanelListsAGroupsAccountsInItsSort() async throws {
        let work = account(.claude, "Claude Work"), personal = account(.codex, "Codex Personal"), side = account(.claude, "Claude Side")
        let hidden = account(.claude, "Claude Hidden")
        // Never signed in to Limi, so its row reads "--".
        let old = UsageAccount(id: UUID(), provider: .codex, name: "Codex Old")
        let f = try SortFixture([work, personal, side, old, hidden], usage: [
            work.id: snapshot(fiveHour: window(30, resetsIn: 200), weekly: window(40, resetsIn: 3_000)),
            personal.id: snapshot(.codex, fiveHour: window(5, resetsIn: 90), weekly: window(90, resetsIn: 6_000)),
            side.id: snapshot(fiveHour: window(60, resetsIn: 20)),
            hidden.id: snapshot(fiveHour: window(99, resetsIn: 1)),
        ]); defer { f.close() }
        let group = MenuBarLayout(name: "All", rows: [line(work, slot: 0)], memberIDs: [work, personal, side, old, hidden].map(\.id))
        f.store.updateDisplay { $0.layouts = [group]; $0.setVisible(hidden.id, false) }
        await f.store.refresh()
        #expect(f.store.snapshots.count == 3)
        func listed() throws -> [UUID] {
            f.store.sortedPanelAccountIDs(for: try #require(f.store.displayConfiguration.layouts?.first), now: now)
        }
        // Manual is the panel's list as it was: the group's order, without the hidden account.
        let panel = f.store.panelAccountIDs(for: try #require(f.store.displayConfiguration.layouts?.first))
        #expect(panel == [work, personal, side, old].map(\.id))
        #expect(try listed() == panel)
        f.store.setListSort(.usage, for: group.id)
        #expect(try listed() == [personal, side, work, old].map(\.id))
        f.store.setListSort(.resetTime, for: group.id)
        #expect(try listed() == [side, personal, work, old].map(\.id))
    }
}

// A whole minute, so a reset a whole number of minutes away reads exactly as set.
private let now = Date(timeIntervalSinceReferenceDate: 13_000_000 * 60)

/// A limit `percent` used, resetting `minutes` from `now` (before it when negative), or without a reset time.
private func window(_ percent: Double, resetsIn minutes: Double? = nil) -> WindowSummary {
    WindowSummary(tokens: Int((percent * 10).rounded()), limitTokens: 1_000,
                  resetAt: minutes.map { now.addingTimeInterval($0 * 60) }, displayStyle: .percentage)
}

private func snapshot(_ provider: ProviderKind = .claude, fiveHour: WindowSummary? = nil, weekly: WindowSummary? = nil,
                      models: [ModelWeeklySummary] = [], stale: Bool = false) -> ProviderSnapshot {
    ProviderSnapshot(provider: provider, updatedAt: now, fiveHour: fiveHour, weekly: weekly, modelWeeklies: models,
                     planName: nil, sourceDescription: "Test", note: nil, isStale: stale, requiresLogin: false)
}

private func account(_ provider: ProviderKind, _ name: String) -> UsageAccount {
    UsageAccount(id: UUID(), provider: provider, name: name, credentialID: UUID())
}

/// A line that already carries its badge, so reading a file does not change it.
private func line(_ account: UsageAccount, slot: Int) -> MenuBarLine {
    MenuBarLine(accountID: account.id, metricID: "weekly", slot: slot, badgeText: account.name)
}

/// A display file with one group, `extra` added to the group.
private func file(_ account: UUID, _ group: UUID, _ extra: String = "") -> Data {
    Data("""
    {"version":2,"order":["\(account)"],"accounts":{"\(account)":{"badge":"CL","color":"blue"}},
     "layouts":[{"id":"\(group)","name":"Work","enabled":true,"style":"bars","showBadge":true,"showBar":true,
       "showPercent":true,"rowsPerColumn":3,"rows":[{"id":"line","accountID":"\(account)","metricID":"weekly","slot":0}]\(extra)}]}
    """.utf8)
}

@MainActor
private final class SortFixture {
    let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("list-sort-\(UUID())"))
    let suite = "list-sort-\(UUID())"
    let defaults: UserDefaults
    let settings: AppSettings
    let accounts: [UsageAccount]
    let store: UsageStore
    init(_ accounts: [UsageAccount] = [account(.claude, "Claude Work"), account(.codex, "Codex Personal"), account(.claude, "Claude Side")],
         usage: [UUID: ProviderSnapshot] = [:]) throws {
        self.accounts = accounts
        defaults = UserDefaults(suiteName: suite)!
        settings = AppSettings(defaults: defaults)
        var registry = AccountRegistry(accounts: accounts); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        store = UsageStore(settings: settings, files: files, autoRefresh: false, loadAccount: { account, _ in
            usage[account.id] ?? .placeholder(for: account.provider)
        })
    }
    /// Another store reading what has been saved, as the next launch does.
    func reopened() -> UsageStore { UsageStore(settings: settings, files: files, autoRefresh: false) }
    func close() { store.shutdown(); try? FileManager.default.removeItem(at: files.root); defaults.removePersistentDomain(forName: suite) }
}
