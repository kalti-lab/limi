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

    // Eight groups, one per account as adding accounts leaves them, are wider than Settings. The preview and the
    // tabs keep their size and scroll sideways inside the window with no scroll bar, and picking a group brings it
    // into view in both rows.
    @Test func manyGroupsScrollSidewaysInsideTheWindow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-many-groups-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "agentbar-many-groups-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let files = AccountFiles(root: root)
        let names = ["claude", "claude(회사)", "codex", "PB1", "PB2", "PB3", "PB4", "PB5"]
        let accounts = names.enumerated().map { index, name in
            UsageAccount(id: UUID(), provider: name == "codex" ? .codex : .claude, name: name,
                         identity: .init(email: "user\(index + 1)@example.test"), credentialID: UUID())
        }
        var registry = AccountRegistry(accounts: accounts); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        let usage = Dictionary(uniqueKeysWithValues: zip(accounts.map(\.id), [23, 61, 47, 12, 88, 35, 54, 70]))
        let settings = AppSettings(defaults: defaults)
        let store = UsageStore(settings: settings, files: files, autoRefresh: false) { account, _ in
            let used = usage[account.id] ?? 50
            return ProviderSnapshot(provider: account.provider, updatedAt: .now,
                fiveHour: WindowSummary(tokens: used, limitTokens: 100, resetAt: .now.addingTimeInterval(3600), displayStyle: .percentage),
                weekly: WindowSummary(tokens: used / 2, limitTokens: 100, resetAt: .now.addingTimeInterval(36000), displayStyle: .percentage),
                modelWeeklies: [], planName: "Max", sourceDescription: "Fixture", note: nil, isStale: false, requiresLogin: false)
        }
        // Two lines and the name each, so every group draws in the preview.
        let groups = accounts.map { account in
            MenuBarLayout(name: account.name, style: .bars, badgeMode: .common, rows: [
                MenuBarLine(accountID: account.id, metricID: "5h", slot: 0),
                MenuBarLine(accountID: account.id, metricID: "weekly", slot: 1)])
        }
        store.updateDisplay { $0.editLayouts { $0 = groups } }
        store.refreshNow()
        for _ in 0..<150 where store.snapshots.count < accounts.count { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.snapshots.count == accounts.count)
        #expect(store.displayConfiguration.effectiveLayouts.map(\.name) == names)

        // The test runs on the main queue, so what the rows queue there (bringing a picked group into view) runs only
        // while the test sleeps; and as the window is never shown, nothing lays the view out but the test.
        func settle(_ view: NSView, _ seconds: TimeInterval = 0.8) async throws {
            let end = Date().addingTimeInterval(seconds)
            while Date() < end { view.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
        }
        func scrollViews(in view: NSView) -> [NSScrollView] {
            ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap { scrollViews(in: $0) }
        }
        // How far a row has scrolled, as a share of how far it can.
        func scrolled(_ row: NSScrollView) -> CGFloat {
            let room = (row.documentView?.frame.width ?? 0) - row.contentView.bounds.width
            return room > 0 ? row.contentView.bounds.minX / room : 0
        }
        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            store.selectMenuBarGroup(groups[0].id)
            // A window that is never shown runs no animations, so here a row scrolls at once rather than gliding.
            let host = NSHostingView(rootView: SettingsView(tab: .menuBar).environmentObject(settings).environmentObject(store)
                .background(Color(nsColor: .windowBackgroundColor))
                .transaction { $0.animation = nil })
            host.appearance = NSAppearance(named: appearance)
            // In a window that is never shown, so the rows lay out and scroll in real scroll views as on screen.
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 900), styleMask: [.borderless],
                                  backing: .buffered, defer: true)
            window.contentView = host
            defer { window.contentView = nil }
            host.frame = NSRect(x: 0, y: 0, width: 540, height: 900)
            try await settle(host)

            // The tab's content is no wider than the window, so nothing is cut off on its right.
            let views = scrollViews(in: host)
            let page = try #require(views.max { $0.frame.height < $1.frame.height })
            #expect(host.fittingSize.width == 540)
            #expect((page.documentView?.frame.width ?? .infinity) <= 540)
            // The preview (the taller row) and the tabs scroll inside the window, without a scroll bar even where
            // the Mac shows scroll bars always.
            let rows = views.filter { $0 !== page }.sorted { $0.frame.height > $1.frame.height }
            try #require(rows.count == 2)
            let (preview, tabs) = (rows[0], rows[1])
            for row in rows { row.scrollerStyle = .legacy }
            try await settle(host, 0.3)
            #expect(preview.frame.height == 32 && tabs.frame.height == 28)
            for row in rows {
                let frame = row.convert(row.bounds, to: host)
                #expect(frame.minX >= 0 && frame.maxX <= 540, "\(frame)")
                #expect((row.documentView?.frame.width ?? 0) > row.contentView.bounds.width)
                #expect(!row.hasHorizontalScroller || row.horizontalScroller?.isHidden == true)
            }
            // The preview opens at its right end as the menu bar does; the tabs at the selected first group.
            #expect(scrolled(preview) > 0.99)
            #expect(scrolled(tabs) < 0.01)
            // The last group's tab comes into view; in the preview it is in view at the right end already.
            store.selectMenuBarGroup(groups[7].id); try await settle(host)
            #expect(scrolled(tabs) > 0.01)
            #expect(scrolled(preview) > 0.99)
            // The second group is now left of both rows' views. Both scroll back to it, with more on either side.
            store.selectMenuBarGroup(groups[1].id); try await settle(host)
            for row in rows { #expect(scrolled(row) > 0.01 && scrolled(row) < 0.99, "\(scrolled(row))") }

            let height = min(900, max(400, host.fittingSize.height))
            host.frame = NSRect(x: 0, y: 0, width: 540, height: height)
            try await settle(host, 0.3)
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            #expect(bitmap.pixelsWide > 0)
            if let output {
                try bitmap.representation(using: .png, properties: [:])?
                    .write(to: output.appendingPathComponent("settings-menubar-many-groups-\(name).png"))
            }
        }
    }
}
