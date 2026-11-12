import AppKit
import Foundation
import SwiftUI
import Testing
@testable import agent_bar

@MainActor
struct MenuBarSettingsRenderingTests {
    @Test func menuBarTabRendersGroupsAsTabsWithPreviewInBothAppearances() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-menubar-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "agentbar-menubar-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let files = AccountFiles(root: root)
        let claude = UsageAccount(id: UUID(), provider: .claude, name: "Claude", identity: .init(email: "me@example.test"), credentialID: UUID())
        let codex = UsageAccount(id: UUID(), provider: .codex, name: "Codex", identity: .init(email: "me@example.test"), credentialID: UUID())
        var registry = AccountRegistry(accounts: [claude, codex]); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        let settings = AppSettings(defaults: defaults)
        let store = UsageStore(settings: settings, files: files, autoRefresh: false) { account, _ in
            let used = account.provider == .claude ? 23 : 67
            return ProviderSnapshot(provider: account.provider, updatedAt: .now,
                fiveHour: WindowSummary(tokens: used, limitTokens: 100, resetAt: .now.addingTimeInterval(3600), displayStyle: .percentage),
                weekly: WindowSummary(tokens: used / 2, limitTokens: 100, resetAt: .now.addingTimeInterval(36000), displayStyle: .percentage),
                modelWeeklies: [], planName: "Pro", sourceDescription: "Fixture", note: nil, isStale: false, requiresLogin: false)
        }
        store.refreshNow()
        for _ in 0..<50 where store.snapshots.count < 2 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.snapshots.count == 2)
        let mixed = MenuBarLayout(name: "AI", style: .bars,
            rows: [MenuBarLine(accountID: claude.id, metricID: "5h"), MenuBarLine(accountID: codex.id, metricID: "5h")])
        store.updateDisplay { config in
            config.editLayouts { groups in
                groups.append(mixed)
                if let index = groups.firstIndex(where: { $0.id == mixed.id }) {
                    groups[index].badgeMode = .common; groups[index].commonBadgeText = "AI"
                }
            }
        }
        store.selectMenuBarGroup(mixed.id)
        #expect(store.displayConfiguration.effectiveLayouts.count == 3)

        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let host = NSHostingView(rootView: SettingsView(tab: .menuBar).environmentObject(settings).environmentObject(store)
                .background(Color(nsColor: .windowBackgroundColor)))
            host.appearance = NSAppearance(named: appearance)
            host.frame = NSRect(x: 0, y: 0, width: 540, height: 760)
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            #expect(bitmap.pixelsWide > 0)
            if let output {
                try bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("settings-menubar-\(name).png"))
            }
        }
    }

    @Test func groupEditorDrawsMemberChipsInBothAppearances() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-members-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "agentbar-members-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let files = AccountFiles(root: root)
        // Seven Claude and five Codex accounts, badged CL, CL2… and CX, CX2… as new accounts are.
        let accounts = (0..<12).map { index in
            UsageAccount(id: UUID(), provider: index < 7 ? .claude : .codex, name: "Account \(index + 1)",
                         identity: .init(email: "user\(index + 1)@example.test"), credentialID: UUID())
        }
        var registry = AccountRegistry(accounts: accounts); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        let settings = AppSettings(defaults: defaults)
        let store = UsageStore(settings: settings, files: files, autoRefresh: false) { account, _ in
            let used = account.provider == .claude ? 42 : 18
            return ProviderSnapshot(provider: account.provider, updatedAt: .now,
                fiveHour: WindowSummary(tokens: used, limitTokens: 100, resetAt: .now.addingTimeInterval(3600), displayStyle: .percentage),
                weekly: WindowSummary(tokens: used / 2, limitTokens: 100, resetAt: .now.addingTimeInterval(36000), displayStyle: .percentage),
                modelWeeklies: [], planName: "Max", sourceDescription: "Fixture", note: nil, isStale: false, requiresLogin: false)
        }
        let claude = Array(accounts[..<7]), codex = Array(accounts[7...])
        // Members in an order of their own, as dragged chips leave it; the lines draw three of them.
        let order = [claude[3], claude[1], codex[2], claude[0], codex[1], claude[4], codex[0],
                     claude[2], claude[5], codex[3], claude[6], codex[4]].map(\.id)
        let all = MenuBarLayout(name: "ALL", style: .bars, rows: [
            MenuBarLine(accountID: claude[3].id, metricID: "5h", slot: 0),
            MenuBarLine(accountID: claude[1].id, metricID: "5h", slot: 1),
            MenuBarLine(accountID: codex[2].id, metricID: "weekly", slot: 2)], memberIDs: order)
        // No accounts of its own: its chips are its lines' accounts.
        let pair = MenuBarLayout(name: "Pair", style: .bars, rows: [
            MenuBarLine(accountID: claude[0].id, metricID: "5h", slot: 0),
            MenuBarLine(accountID: codex[0].id, metricID: "weekly", slot: 1)])
        store.updateDisplay { $0.editLayouts { $0 = [all, pair] } }
        #expect(store.displayConfiguration.effectiveLayouts.map(\.id) == [all.id, pair.id])
        #expect(store.groupMembers(all.id) == order)
        #expect(store.groupMembers(pair.id) == [claude[0].id, codex[0].id])
        store.refreshNow()
        for _ in 0..<100 where store.snapshots.count < accounts.count { try await Task.sleep(for: .milliseconds(20)) }

        // Twelve chips wrap onto more rows than the two of a group that follows its lines.
        func sectionHeight(_ id: UUID) throws -> CGFloat {
            let group = try #require(store.displayConfiguration.effectiveLayouts.first { $0.id == id })
            let host = NSHostingView(rootView: GroupMemberSection(group: group).environmentObject(store).frame(width: 472))
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        #expect(try sectionHeight(all.id) > sectionHeight(pair.id) + MemberChip.height)

        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for (group, kind) in [(all, "members"), (pair, "lines")] {
            store.selectMenuBarGroup(group.id)
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let host = NSHostingView(rootView: SettingsView(tab: .menuBar).environmentObject(settings).environmentObject(store)
                    .background(Color(nsColor: .windowBackgroundColor)))
                host.appearance = NSAppearance(named: appearance)
                host.frame = NSRect(x: 0, y: 0, width: 540, height: 900)
                host.layoutSubtreeIfNeeded()
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                #expect(bitmap.pixelsWide > 0)
                if let output {
                    try bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("settings-group-\(kind)-\(name).png"))
                }
            }
        }
        // Drawing changes nothing: the second group still follows its lines.
        #expect(store.displayConfiguration.effectiveLayouts.first { $0.id == pair.id }?.memberIDs == nil)
    }
}
