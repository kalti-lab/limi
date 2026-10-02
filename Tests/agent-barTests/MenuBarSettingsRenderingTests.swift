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
}
