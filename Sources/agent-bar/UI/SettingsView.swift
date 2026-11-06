import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case accounts, menuBar, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .accounts: return "Accounts"
        case .menuBar: return "Menu Bar"
        case .general: return "General"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    @State private var restoring = false
    @State private var tab: SettingsTab
    @StateObject private var launchAtLogin = LaunchAtLogin()
    init(tab: SettingsTab = .accounts) { _tab = State(initialValue: tab) }
    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings", selection: $tab) {
                ForEach(SettingsTab.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20).padding(.top, 14)
            switch tab {
            case .accounts:
                ScrollView { AccountManagementView().padding(20) }
            case .menuBar:
                MenuBarSettingsView()
            case .general:
                Form {
                    Section("Refresh") {
                        Picker("Refresh Interval", selection: $settings.refreshIntervalSeconds) {
                            Text("1 minute").tag(60.0); Text("2 minutes").tag(120.0)
                            Text("5 minutes").tag(300.0); Text("10 minutes").tag(600.0)
                        }
                        Text("Accounts used by a visible menu bar group refresh at this interval.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Startup") {
                        Toggle("Open at Login", isOn: Binding(get: { launchAtLogin.isOn }, set: { launchAtLogin.set($0) }))
                        if launchAtLogin.needsApproval {
                            HStack {
                                Text("Allow AgentBar in Login Items to finish turning this on.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("Open Login Items") { launchAtLogin.openLoginItems() }
                            }
                        }
                        if let error = launchAtLogin.errorMessage {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    if store.hasOriginalDisplayConfiguration {
                        Section("Recovery") {
                            Button("Restore Original Groups…") { restoring = true }
                            Text("Restore the saved layout from before the UX changes. The current layout is backed up first; account names and colors are kept.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        LabeledContent("Version", value: Self.version)
                    }
                }.formStyle(.grouped)
                .onAppear { launchAtLogin.refresh() }
            }
            if tab != .accounts {
                if let error = store.errorMessage {
                    HStack {
                        Text(error).font(.caption).foregroundStyle(.red)
                        Button("Dismiss") { store.errorMessage = nil }
                    }.padding(10)
                }
            }
            if let error = store.displayError {
                Text(error).font(.caption).foregroundStyle(.orange).padding(10)
            }
        }.frame(width: 540, height: 660)
        .alert("Restore the original menu bar layout?", isPresented: $restoring) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") { store.restoreOriginalDisplayConfiguration(); tab = .menuBar }
        } message: { Text("This restores the original groups, account order, selected limits and display options. Your current layout is saved as a backup first.") }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "Development build"
        return (info["CFBundleVersion"] as? String).map { "\(version) (\($0))" } ?? version
    }
}
