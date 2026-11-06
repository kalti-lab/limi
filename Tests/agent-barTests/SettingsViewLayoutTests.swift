import AppKit
import Foundation
import SwiftUI
import Testing
@testable import agent_bar

@MainActor
struct SettingsViewLayoutTests {
    @Test("Settings fits each tab and stops at its maximum")
    func settingsFitsEachTabUpToItsMaximum() {
        let identifier = "SettingsViewLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: identifier)!
        defaults.removePersistentDomain(forName: identifier)
        let providers: [ProviderKind] = [.claude, .codex]
        let settings = AppSettings(availableProviders: providers, defaults: defaults)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: identifier) }
        let store = UsageStore(settings: settings, files: AccountFiles(root: root), autoRefresh: false)
        // Measured off screen; nothing is shown.
        func size(_ tab: SettingsTab, maximum: CGFloat = 700) -> CGSize {
            NSHostingView(rootView: SettingsView(tab: tab, maxContentHeight: maximum)
                .environmentObject(settings)
                .environmentObject(store)).fittingSize
        }

        let accounts = size(.accounts)
        #expect(accounts.width == 540)
        // No accounts: a short window instead of the old fixed 660.
        #expect(accounts.height < 320)
        let general = size(.general)
        #expect(general.height > accounts.height && general.height <= 700 + 60)
        // Content taller than its room scrolls; the window does not grow past it.
        #expect(size(.general, maximum: 100).height <= 100 + 60)
    }
}

private struct SettingsLayoutUsageProvider: UsageProviding {
    let provider: ProviderKind

    func load() async -> ProviderSnapshot {
        .placeholder(for: provider)
    }
}
