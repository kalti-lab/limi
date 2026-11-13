import AppKit
import Foundation
import SwiftUI
import Testing
@testable import agent_bar

@MainActor
struct GroupAccountListRenderingTests {
    private static let now = Date()
    private static let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

    @Test func listDrawsEveryRowState() async throws {
        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }

        // The cells: what the service reports, in its order; "--" for both usual limits before anything is read.
        #expect(GroupAccountRow.cellMetrics(Self.usage(.claude, 42, 21, models: [("Fable", 40)])).map(\.cellTitle) == ["5h", "Week", "Fable"])
        #expect(GroupAccountRow.cellMetrics(Self.usage(.claude, 42, 21)).map(\.cellTitle) == ["5h", "Week"])
        #expect(GroupAccountRow.cellMetrics(Self.antigravity).map(\.cellTitle) == ["Gemini 5h", "Gemini wk", "Claude/GPT 5h", "Claude/GPT wk"])
        let unread = GroupAccountRow.cellMetrics(.placeholder(for: .codex))
        #expect(unread.map(\.cellTitle) == ["5h", "Week"] && unread.allSatisfy { $0.window?.utilization == nil })

        // Rows line up: the pointer, a Claude Code button or its absence never change a row's height. A fourth limit
        // starts a second line of cells.
        let states = Self.rowStates()
        func height(_ name: String, highlighted: Bool? = nil) throws -> CGFloat {
            var row = try #require(states.first { $0.0 == name }?.1)
            if let highlighted { row.highlighted = highlighted }
            return NSHostingView(rootView: row.frame(width: GroupAccountListView.width)).fittingSize.height
        }
        for name in ["Over 90% · pointer on Use", "Set Up · pointer"] {
            #expect(try height(name, highlighted: false) == height(name, highlighted: true), "\(name)")
        }
        #expect(try height("Claude · In use · three limits") == height("Over 90% · pointer on Use"))
        #expect(try height("Codex · two limits") == height("Claude · In use · three limits"))
        #expect(try height("Antigravity · four limits") > height("Codex · two limits") + 20)

        for (name, appearance) in Self.appearances {
            let sheet = VStack(alignment: .leading, spacing: 2) {
                ForEach(states.indices, id: \.self) { index in
                    Text(verbatim: states[index].0).font(.caption2).foregroundStyle(.tertiary).padding(.leading, 14).padding(.top, 6)
                    states[index].1
                }
            }
            .padding(.horizontal, 6).padding(.bottom, 8)
            .frame(width: GroupAccountListView.width)
            try await draw(sheet, appearance: appearance, to: output?.appendingPathComponent("group-list-rows-\(name).png"))
        }
    }

    @Test func twelveAccountsListInTheGroupsOrderAndScrollWhenTheScreenIsShort() async throws {
        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        // Seven Claude and five Codex accounts, badged CL, CL2… and CX, CX2… as new accounts are.
        let f = try SwitchFixture()
        let claude = ["cl", "cl2", "cl3", "cl4", "cl5", "cl6", "cl7"].map { f.addAccount($0) }
        let codex = ["cx", "cx2", "cx3", "cx4", "cx5"].map {
            UsageAccount(id: UUID(), provider: .codex, name: $0, identity: .init(email: "\($0)@example.test"), credentialID: UUID())
        }
        // Claude Code uses CL2, and CL4 is ready to take over.
        f.signInDefault(claude[1])
        try f.saveLogin(for: claude[3])
        var registry = AccountRegistry(accounts: f.accounts + codex); registry.repairRepresentatives()
        try f.files.write(registry, to: f.files.registryURL)
        let usage: [UUID: ProviderSnapshot] = [
            claude[3].id: Self.usage(.claude, 92, 64, models: [("Fable", 40)], plan: "Max"),
            claude[1].id: Self.usage(.claude, 88, 64, models: [("Fable", 40)], plan: "Max"),
            codex[2].id: Self.usage(.codex, 64, 22, plan: "Team"),
            claude[0].id: Self.usage(.claude, 42, 21, plan: "Team"),
            codex[1].id: Self.usage(.codex, 30, 48, plan: "Plus"),
            claude[4].id: Self.usage(.claude, 17, 9, plan: "Pro"),
            codex[0].id: Self.usage(.codex, 12, 5, plan: "Team"),
            claude[2].id: Self.usage(.claude, 35, 18, plan: "Pro", updated: Self.now.addingTimeInterval(-300), stale: true,
                                     note: "Too many requests. Showing cached usage."),
            claude[5].id: Self.usage(.claude, 55, 30, models: [("Fable", 12)], plan: "Max"),
            codex[3].id: Self.usage(.codex, 40, 10, plan: "Plus", stale: true, login: true, note: "Sign in again in Settings › Accounts."),
            claude[6].id: Self.usage(.claude, 8, 3, plan: "Pro"),
            codex[4].id: ProviderSnapshot.placeholder(for: .codex).failed("Codex did not answer. Try again later."),
        ]
        let suite = "group-list-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        let store = UsageStore(settings: AppSettings(defaults: defaults), files: f.files, autoRefresh: false,
                               loadAccount: { account, _ in usage[account.id] ?? .placeholder(for: account.provider) },
                               claudeCode: f.switcher, claudeCodeBrowser: BrowserLoginLauncher(openURL: { _ in true }))
        defer { store.shutdown(); defaults.removePersistentDomain(forName: suite) }
        await store.runClaudeCodeStartup()

        // The order chips were dragged into; the lines draw three of the twelve.
        let order = [claude[3], claude[1], codex[2], claude[0], codex[1], claude[4], codex[0],
                     claude[2], claude[5], codex[3], claude[6], codex[4]].map(\.id)
        let all = MenuBarLayout(name: "ALL", style: .bars, rows: [
            MenuBarLine(accountID: claude[3].id, metricID: "5h", slot: 0),
            MenuBarLine(accountID: claude[1].id, metricID: "5h", slot: 1),
            MenuBarLine(accountID: codex[2].id, metricID: "weekly", slot: 2)], memberIDs: order)
        store.updateDisplay { $0.editLayouts { $0 = [all] } }
        store.refreshNow()
        for _ in 0..<250 where store.snapshots.count < order.count { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.snapshots.count == order.count)
        let layout = try #require(store.displayConfiguration.effectiveLayouts.first { $0.id == all.id })
        let panel = store.groupPanel(for: layout)
        #expect(panel == GroupPanelContent(mode: .list, accountIDs: order))
        #expect(store.claudeCodeListRow(for: claude[1]).control == .inClaudeCode)
        guard case .use(enabled: true, _) = store.claudeCodeListRow(for: claude[3]).control else {
            Issue.record("CL4 should be ready for Claude Code"); return
        }

        // The pointer rests on CL4, the first row, so its Use button shows.
        let list = GroupAccountListView(accountIDs: panel.accountIDs, groupID: all.id, hovered: claude[3].id).environmentObject(store)
        for (name, appearance) in Self.appearances {
            let whole = try await draw(list, appearance: appearance, to: output?.appendingPathComponent("group-list-\(name).png"))
            #expect(whole.width == GroupAccountListView.width)
            // A screen shorter than the list: the rows scroll between the header and the footer, which stay.
            #expect(whole.height > 560)
            try await draw(list, appearance: appearance, height: 560, to: output?.appendingPathComponent("group-list-scroll-\(name).png"))
        }
    }

    // MARK: Fixtures

    private static func usage(_ provider: ProviderKind, _ fiveHour: Int?, _ weekly: Int?, models: [(String, Int)] = [], plan: String? = nil,
                              groups: [LimitGroupSummary]? = nil, updated: Date = now.addingTimeInterval(-60), stale: Bool = false,
                              login: Bool = false, note: String? = nil) -> ProviderSnapshot {
        ProviderSnapshot(provider: provider, updatedAt: updated, fiveHour: window(fiveHour, hours: 2.7), weekly: window(weekly, hours: 130),
                         modelWeeklies: models.compactMap { model in window(model.1, hours: 74).map { ModelWeeklySummary(label: model.0, window: $0) } },
                         planName: plan, sourceDescription: "Fixture", note: note, isStale: stale, requiresLogin: login, limitGroups: groups)
    }

    private static func window(_ used: Int?, hours: Double) -> WindowSummary? {
        used.map { WindowSummary(tokens: $0, limitTokens: 100, resetAt: now.addingTimeInterval(hours * 3600), displayStyle: .percentage) }
    }

    private static var antigravity: ProviderSnapshot {
        let gemini = LimitGroupSummary(label: "Gemini", fiveHour: window(30, hours: 3), weekly: window(12, hours: 100))
        let claude = LimitGroupSummary(label: "Claude/GPT", fiveHour: window(55, hours: 1), weekly: window(91, hours: 40))
        return usage(.antigravity, 30, 12, plan: "Pro", groups: [gemini, claude])
    }

    // Every state a row can be in, as the plan's tables list them: limits and their alert, unread, cached and signed-out
    // usage, then each Claude Code state.
    private static func rowStates() -> [(String, GroupAccountRow)] {
        let claude = usage(.claude, 42, 21, models: [("Fable", 40)], plan: "Max")
        let switching = String(localized: "Claude Code is being switched. Wait for it to finish.")
        let reconnect = String(localized: "Reconnect this account before using it in Claude Code.")
        let useHelp = "Switches Claude Code to this account. Open sessions switch within 30 s."
        func row(_ badge: String, _ address: String, _ snapshot: ProviderSnapshot, _ control: ClaudeCodePanel.Control = .hidden,
                 _ lines: [ClaudeCodePanel.Line] = [], pointer: Bool = false, refreshing: Bool = false) -> GroupAccountRow {
            GroupAccountRow(provider: snapshot.provider, badge: badge, address: address, snapshot: snapshot, refreshing: refreshing,
                            claudeCode: ClaudeCodePanel(control: control, lines: lines), highlighted: pointer)
        }
        return [
            ("Claude · In use · three limits", row("CL2", "me@example.com", claude, .inClaudeCode)),
            ("Codex · two limits", row("CX3", "ops@example.com", usage(.codex, 64, 22, plan: "Team"))),
            ("Antigravity · four limits", row("AG", "studio@example.com", antigravity)),
            ("Over 90% · pointer on Use", row("CL4", "team4@example.com", usage(.claude, 92, 64, models: [("Fable", 40)], plan: "Max"),
                                              .use(enabled: true, help: useHelp), pointer: true)),
            ("Long address · pointer on Use", row("CL5", "a-very-long-address-for-a-team-account@example-company.com",
                                                  usage(.claude, 17, 9, plan: "Pro"), .use(enabled: true, help: useHelp), pointer: true)),
            ("Loading", row("CX4", "new@example.com", .placeholder(for: .codex), refreshing: true)),
            ("Could not load", row("CX5", "lab@example.com", ProviderSnapshot.placeholder(for: .codex).failed("Codex did not answer. Try again later."))),
            ("Cached", row("CL3", "lab@example.com", usage(.claude, 35, 18, models: [("Fable", 20)], plan: "Pro", updated: now.addingTimeInterval(-300),
                                                         stale: true, note: "Too many requests. Showing cached usage."))),
            ("Sign-in required", row("CX2", "dev@example.com", usage(.codex, 40, 10, plan: "Plus", stale: true, login: true,
                                                                    note: "Sign in again in Settings › Accounts."))),
            ("Use · checking · pointer", row("CL6", "six@example.com", claude, .use(enabled: false, help: String(localized: "Checking Claude Code…")), pointer: true)),
            ("Use · reconnect first · pointer", row("CL7", "seven@example.com", claude, .use(enabled: false, help: reconnect), [.notice(reconnect)], pointer: true)),
            ("Set Up · pointer", row("CL", "work@example.com", claude,
                                     .setUp(help: String(localized: "Sign in once in Settings › Accounts so Claude Code can use this account.")), pointer: true)),
            ("Switching · this account", row("CL4", "team4@example.com", claude, .use(enabled: false, help: switching),
                                             [.progress(String(localized: "Reading the current Claude Code login…"))])),
            ("Switching · another account · pointer", row("CL5", "lab@example.com", claude, .use(enabled: false, help: switching), pointer: true)),
            ("Question", row("CL4", "team4@example.com", claude, .use(enabled: true, help: useHelp), [.confirmation(email: "old@example.com")])),
            ("Switched", row("CL4", "team4@example.com", claude, .inClaudeCode, [.result(succeeded: true, message: "Claude Code now uses team4@example.com.")])),
            ("Switch failed", row("CL4", "team4@example.com", claude, .use(enabled: true, help: useHelp),
                                  [.result(succeeded: false, message: "Couldn't switch Claude Code. Its login was not changed.")])),
        ]
    }

    // Gives the main actor back before each picture, so tests running alongside are not kept waiting on it.
    @discardableResult
    private func draw<V: View>(_ view: V, appearance: NSAppearance.Name, height: CGFloat? = nil, to url: URL?) async throws -> NSSize {
        await Task.yield()
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        let size = host.fittingSize
        host.frame = NSRect(x: 0, y: 0, width: size.width, height: height ?? size.height)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
        if let url { try bitmap.representation(using: .png, properties: [:])?.write(to: url) }
        return size
    }
}
