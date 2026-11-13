import AppKit
import SwiftUI

// What the account list says that the rest of the app does not, together while the words are still being settled.
enum GroupListWords {
    static var use: String { String(localized: "Use") }
    static var inUse: String { String(localized: "In use") }
    // On the pointer over Use.
    static var useHelp: String { String(localized: "Use this account in Claude Code. Open sessions switch within 30 s.") }
    // Separate sentences for one and many, since Korean does not add an "s".
    static func accounts(_ count: Int) -> String {
        count == 1 ? String(localized: "1 account") : String(localized: "\(count) accounts")
    }
}

// A group that holds accounts beyond its menu bar lines shows them all on one sheet, in the group's order: a row per
// account with every limit its service reports. There is no detail view behind a row.
struct GroupAccountListView: View {
    static let width: CGFloat = 400

    let accountIDs: [UUID]
    let groupID: UUID
    @EnvironmentObject private var store: UsageStore
    @State private var hovered: UUID?

    // `hovered` is the row the pointer starts over, for drawing that look.
    init(accountIDs: [UUID], groupID: UUID, hovered: UUID? = nil) {
        self.accountIDs = accountIDs
        self.groupID = groupID
        _hovered = State(initialValue: hovered)
    }

    private var accounts: [UsageAccount] {
        MenuBarLayout.unique(accountIDs).compactMap { id in store.accounts.first { $0.id == id && !$0.deletionPending } }
    }

    var body: some View {
        let accounts = accounts
        let claudeCode = Dictionary(accounts.map { ($0.id, store.claudeCodeListRow(for: $0)) }, uniquingKeysWith: { first, _ in first })
        VStack(alignment: .leading, spacing: 0) {
            header(accounts)
            ScrollViewReader { proxy in
                // Scroll only when the rows outgrow the screen; the header and footer stay put.
                ViewThatFits(in: .vertical) {
                    rowList(accounts, claudeCode: claudeCode)
                    ScrollView { rowList(accounts, claudeCode: claudeCode) }
                }
                // A row that comes to hold a result or a question is scrolled into view, so it counts as seen for real.
                .onChange(of: Self.rowsAsking(accounts, claudeCode: claudeCode)) { old, new in
                    guard let id = new.first(where: { !old.contains($0) }) else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
            Divider().padding(.horizontal, 14)
            footer(accounts)
        }
        .frame(width: Self.width, alignment: .topLeading)
        // The list shows all of its Claude accounts at once, for the Claude Code result lines; one that comes to hold a
        // result is scrolled to above. The group is part of the key: a menu bar item that comes to show another group
        // keeps this view.
        .onChange(of: [groupID] + accountIDs, initial: true) { _, _ in
            store.claudeCodePanelShows(self.accounts.filter { $0.provider == .claude }.map(\.id), group: groupID)
        }
    }

    private static func rowsAsking(_ accounts: [UsageAccount], claudeCode: [UUID: ClaudeCodePanel]) -> [UUID] {
        accounts.map(\.id).filter { id in
            claudeCode[id]?.lines.contains { line in
                switch line {
                case .confirmation, .result: return true
                case .progress, .notice: return false
                }
            } == true
        }
    }

    private func header(_ accounts: [UsageAccount]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    let name = store.displayConfiguration.effectiveLayouts.first { $0.id == groupID }?.name ?? ""
                    Group { if name.isEmpty { Text("Untitled") } else { Text(verbatim: name) } }
                        .font(.headline).lineLimit(1)
                    Text(GroupListWords.accounts(accounts.count))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                }
                Spacer(minLength: 8)
                // Side by side, so their hover backgrounds touch, as in the tabs' header.
                HStack(spacing: 0) {
                    if accounts.contains(where: { store.refreshingAccounts.contains($0.id) }) {
                        // The room the refresh button takes, so the header does not shift while it turns.
                        ProgressView().controlSize(.small).frame(width: 24, height: 24)
                    } else {
                        Button { store.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                            .help("Refresh now")
                    }
                    Button { SettingsWindowController.shared.show(tab: .menuBar, groupID: groupID) } label: { Image(systemName: "gearshape") }
                        .help("Settings")
                }
                .buttonStyle(PanelButtonStyle(kind: .icon))
                .padding(.trailing, -4)
            }
            if let error = store.displayError {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            // Said once for every Claude account, such as a Claude Code too old to switch.
            if let notice = store.claudeCodeListNotice, accounts.contains(where: { $0.provider == .claude }) {
                Text(notice).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func rowList(_ accounts: [UsageAccount], claudeCode: [UUID: ClaudeCodePanel]) -> some View {
        let refreshed = store.refreshAccountIDs
        return VStack(spacing: 0) {
            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                if index > 0 {
                    // Gone beside the row under the pointer, whose background marks it instead.
                    Divider().padding(.horizontal, 8)
                        .opacity(hovered == account.id || hovered == accounts[index - 1].id ? 0 : 1)
                }
                row(account, refreshed: refreshed.contains(account.id), claudeCode: claudeCode[account.id] ?? .hidden)
                    .id(account.id)
                    .onHover { inside in
                        if inside { hovered = account.id } else if hovered == account.id { hovered = nil }
                    }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func row(_ account: UsageAccount, refreshed: Bool, claudeCode: ClaudeCodePanel) -> some View {
        GroupAccountRow(
            provider: account.provider,
            badge: store.displayConfiguration.display(account).badge,
            address: account.identity?.email.flatMap { $0.isEmpty ? nil : $0 } ?? store.accountLabel(for: account),
            snapshot: store.snapshot(for: account),
            refreshed: refreshed,
            refreshing: store.refreshingAccounts.contains(account.id),
            claudeCode: claudeCode,
            highlighted: hovered == account.id,
            actions: .init(use: { store.useInClaudeCode(account) },
                           setUp: { SettingsWindowController.shared.show(tab: .accounts, groupID: groupID) },
                           confirm: { store.confirmClaudeCodeSwitch() },
                           decline: { store.cancelClaudeCodeConfirmation() },
                           openLog: { store.openClaudeCodeLog() }))
    }

    private func footer(_ accounts: [UsageAccount]) -> some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(verbatim: updated(accounts, now: context.date))
                    .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
            }
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // The oldest time among the accounts that are up to date: every one of them is at least that fresh. Accounts that
    // could not be refreshed say so in their own rows.
    private func updated(_ accounts: [UsageAccount], now: Date) -> String {
        if store.isRefreshing { return String(localized: "Refreshing…") }
        guard let oldest = accounts.map({ store.snapshot(for: $0) }).filter({ !$0.isStale }).map(\.updatedAt).min() else { return "" }
        return String(localized: "Updated \(TokenFormatters.relativeUpdateString(from: now, updatedAt: oldest))")
    }
}
