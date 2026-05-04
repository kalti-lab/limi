import AppKit
import SwiftUI

@main
struct AgentBarApp: App {
    @StateObject private var store = AppContainer.shared.store
    @StateObject private var settings = AppContainer.shared.settings

    private let availableProviders = AppContainer.shared.availableProviders

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(availableProviders.contains(.claude))) {
            ProviderPopoverView(snapshot: store.claudeSnapshot)
                .environmentObject(store)
                .environmentObject(settings)
        } label: {
            MenuBarLabelView(provider: .claude)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(availableProviders.contains(.codex))) {
            ProviderPopoverView(snapshot: store.codexSnapshot)
                .environmentObject(store)
                .environmentObject(settings)
        } label: {
            MenuBarLabelView(provider: .codex)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
