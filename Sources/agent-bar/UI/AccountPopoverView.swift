import AppKit
import SwiftUI

// Clicking a menu bar item shows its group. Tabs above the header name the
// group's accounts, even a single one, and switch between them.
struct AccountPopoverView: View {
    static let width: CGFloat = 300

    let accountIDs: [UUID]
    let groupID: UUID?
    @EnvironmentObject private var store: UsageStore
    @State private var selected: UUID?
    init(accountID: UUID, groupID: UUID? = nil) { self.accountIDs = [accountID]; self.groupID = groupID }
    init(accountIDs: [UUID], groupID: UUID? = nil) { self.accountIDs = accountIDs; self.groupID = groupID }
    private var accounts: [UsageAccount] { accountIDs.compactMap { id in store.accounts.first { $0.id == id && !$0.deletionPending } } }
    private var account: UsageAccount? { accounts.first { $0.id == selected } ?? accounts.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !accounts.isEmpty {
                Picker("Account", selection: Binding(get: { account?.id ?? accounts[0].id }, set: { selected = $0 })) {
                    ForEach(accounts) { Text(store.displayConfiguration.display($0).badge).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if let account {
                header(account)
                let claudeCodeLines = store.claudeCodePanel(for: account).lines
                if !claudeCodeLines.isEmpty {
                    ClaudeCodeLinesView(lines: claudeCodeLines, confirm: { store.confirmClaudeCodeSwitch() },
                                        decline: { store.cancelClaudeCodeConfirmation() }, openLog: { store.openClaudeCodeLog() })
                }
                Divider()
                // Scroll only when the cards outgrow the screen.
                ViewThatFits(in: .vertical) {
                    content(account)
                    ScrollView { content(account) }
                }
            } else {
                Text("This account was removed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: Self.width, alignment: .topLeading)
        // Which account the panel shows, for the Claude Code result lines. The group is part of the key: a menu bar item
        // that comes to show another group keeps this view.
        .onChange(of: [groupID, account?.id], initial: true) { _, _ in
            if let id = account?.id, let groupID { store.claudeCodePanelShows(id, group: groupID) }
        }
    }

    private func header(_ account: UsageAccount) -> some View {
        // The tabs above name the account, so the header does not repeat its badge.
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(account.title)
                    .font(.headline)
                    .lineLimit(1)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(account.provider.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ClaudeCodeControlView(control: store.claudeCodePanel(for: account).control,
                                          use: { store.useInClaudeCode(account) },
                                          setUp: { SettingsWindowController.shared.show(tab: .accounts, groupID: groupID) })
                    // As tall as a line with the Claude Code button, so the header keeps its height across tabs and states.
                    ClaudeCodeControlView.heightTemplate
                }
            }
            Spacer(minLength: 8)
            // Side by side, so their hover backgrounds touch and the icons keep their old spacing.
            HStack(spacing: 0) {
                if store.refreshingAccounts.contains(account.id) {
                    // The room the refresh button takes, so the header does not shift while it turns.
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                } else {
                    Button { store.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Refresh now")
                }
                Button { SettingsWindowController.shared.show(tab: .menuBar, groupID: groupID) } label: { Image(systemName: "gearshape") }
                    .help("Settings")
            }
            .buttonStyle(PanelButtonStyle(kind: .icon))
            // The icons stay where they were; only their hover background reaches past them.
            .padding(.trailing, -4)
        }
    }

    @ViewBuilder private func content(_ account: UsageAccount) -> some View {
        let snapshot = store.snapshot(for: account)
        let metrics = DisplayMetric.all(snapshot)
        VStack(alignment: .leading, spacing: 12) {
            if let error = store.displayError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            let shown = metrics.filter { $0.window?.utilization != nil }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, metric in
                if index > 0 { Divider() }
                if let window = metric.window {
                    WindowCard(title: metric.localizedTitle, systemImage: metric.systemImage, window: window)
                }
            }
            ForEach(metrics.filter { $0.window?.utilization == nil && $0.id.hasPrefix("model:") }) { metric in
                Label("\(metric.localizedTitle) · no data yet", systemImage: metric.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(statusLine(snapshot))
                .font(.caption)
                .foregroundStyle(snapshot.requiresLogin || snapshot.isStale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusLine(_ snapshot: ProviderSnapshot) -> String {
        let updated = String(localized: "Updated \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))")
        if snapshot.requiresLogin { return String(localized: "Sign-in required · reconnect in Settings › Accounts") }
        if snapshot.isStale { return (snapshot.note ?? String(localized: "Cached usage.")) + " · " + updated }
        return updated + (snapshot.planName.map { " · " + $0 } ?? "")
    }

    private var footer: some View {
        HStack {
            let count = store.visibleAccounts.count
            // Separate sentences for one and many, since Korean does not add an "s".
            Text(store.isRefreshing ? String(localized: "Refreshing…")
                 : count == 1 ? String(localized: "1 account in menu bar") : String(localized: "\(count) accounts in menu bar"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                Button("Accounts…") { SettingsWindowController.shared.show(tab: .accounts, groupID: groupID) }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(PanelButtonStyle(kind: .text))
            .padding(.trailing, -6)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

struct AccountBadge: View {
    let text: String
    let color: AccountColor
    var compact = false
    var body: some View {
        Text(text)
            .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 5 : 7).frame(height: compact ? 16 : 22)
            .background(RoundedRectangle(cornerRadius: compact ? 4 : 6, style: .continuous).fill(color.color))
            .lineLimit(1).fixedSize()
    }
}
