import AppKit
import SwiftUI

// Clicking a menu bar item shows one account. A grouped item holds several,
// switched with tabs above the header.
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
            if accounts.count > 1 {
                Picker("Account", selection: Binding(get: { account?.id ?? accounts[0].id }, set: { selected = $0 })) {
                    ForEach(accounts) { Text(store.displayConfiguration.display($0).badge).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if let account {
                header(account)
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
    }

    private func header(_ account: UsageAccount) -> some View {
        let display = store.displayConfiguration.display(account)
        return HStack(spacing: 8) {
            AccountBadge(text: display.badge, color: display.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.title)
                    .font(.headline)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(account.provider.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if store.refreshingAccounts.contains(account.id) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button { store.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh now")
            }
            Button { SettingsWindowController.shared.show(tab: .menuBar, groupID: groupID) } label: { Image(systemName: "gearshape") }
                .help("Settings")
        }
        .buttonStyle(.borderless)
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
                    WindowCard(title: metric.title, systemImage: metric.systemImage, window: window)
                }
            }
            ForEach(metrics.filter { $0.window?.utilization == nil && $0.id.hasPrefix("model:") }) { metric in
                Label("\(metric.title) · no data yet", systemImage: metric.systemImage)
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
        let updated = "Updated \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))"
        if snapshot.requiresLogin { return "Sign-in required · reconnect in Settings › Accounts" }
        if snapshot.isStale { return (snapshot.note ?? "Cached usage.") + " · " + updated }
        return updated + (snapshot.planName.map { " · " + $0 } ?? "")
    }

    private var footer: some View {
        HStack {
            let count = store.visibleAccounts.count
            Text(store.isRefreshing ? "Refreshing…" : "\(count) account\(count == 1 ? "" : "s") in menu bar")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("Accounts…") { SettingsWindowController.shared.show(tab: .accounts, groupID: groupID) }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
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
