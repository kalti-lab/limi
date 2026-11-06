import SwiftUI

private struct AccountFrames: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// Accounts manage identities; menu bar groups control display and polling.
struct AccountManagementView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var editing: UsageAccount?
    @State private var deleting: UsageAccount?
    @State private var choosingProvider = false
    @State private var accountFrames: [UUID: CGRect] = [:]
    @State private var accountDrag: ReorderDragPreview<UUID>?
    @State private var settlingAccountDrag = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Errors show in the banner at the top of Settings.
            if store.isLoggingIn || store.pendingLogin != nil { LoginProgressView() }

            // One section holds every account, split by dividers like the
            // system's account lists, instead of separate white cards.
            SettingsSection {
                if store.orderedAccounts.isEmpty {
                    SettingsRow {
                        Text("No accounts yet. Add one to see its usage in the menu bar.").foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(store.orderedAccounts.enumerated()), id: \.element.id) { index, account in
                        SettingsRow(divided: index > 0) { row(account) }
                            .background(GeometryReader { proxy in
                                Color.clear.preference(key: AccountFrames.self, value: [account.id: proxy.frame(in: .named("account-order"))])
                            })
                            .opacity(accountDrag?.source == account.id ? 0 : 1)
                            .offset(accountDrag?.offset(for: account.id) ?? .zero)
                            .animation(.snappy(duration: 0.18), value: accountDrag?.target)
                    }
                }
                .coordinateSpace(name: "account-order")
                .onPreferenceChange(AccountFrames.self) { accountFrames = $0 }
                .overlay(alignment: .topLeading) { accountDragOverlay.allowsHitTesting(false) }
                .zIndex(accountDrag == nil ? 0 : 1)
            }
            HStack {
                if (!store.registry.cleanupPending.isEmpty || store.accounts.contains(where: \.deletionPending))
                    && !store.isLoggingIn && store.pendingLogin == nil {
                    Button("Retry Pending Cleanup") { Task { await store.retryCleanup() } }
                }
                if !store.canAddAccount {
                    Label(UsageStore.accountLimitMessage, systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Add Account…") { choosingProvider = true }
                    .disabled(store.isLoggingIn || store.pendingLogin != nil || store.storageUnavailable || !store.canAddAccount)
            }
        }
        .onDisappear { accountDrag = nil; settlingAccountDrag = false }
        .sheet(item: $editing) { account in AccountEditSheet(account: account, displayName: store.accountLabel(for: account)) }
        .sheet(isPresented: $choosingProvider) {
            AddAccountProviderSheet { provider in store.startLogin(provider) }
        }
        .alert("Delete this account from AgentBar?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let account = deleting { Task { await store.delete(account) } }; deleting = nil
            }
        } message: { Text("This removes only the selected account’s AgentBar credentials and usage cache. External CLI sign-ins are preserved.") }
    }
    private func row(_ account: UsageAccount, preview: Bool = false) -> some View {
        let snapshot = store.snapshot(for: account)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .frame(width: 14, height: 22).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("account-order"))
                    .onChanged { if !preview { updateAccountDrag(account.id, value: $0) } }
                    .onEnded { if !preview { finishAccountDrag(at: $0.location) } })
                .help("Drag to reorder accounts")
                .accessibilityLabel("Move \(store.accountLabel(for: account)) account")
                .accessibilityAction(named: "Move up") { moveAccount(account.id, offset: -1) }
                .accessibilityAction(named: "Move down") { moveAccount(account.id, offset: 1) }
            ProviderMark(provider: account.provider)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button { editing = account } label: {
                        Text(store.accountLabel(for: account)).font(.headline).lineLimit(1)
                    }.buttonStyle(.plain).help("Rename account")
                    if let plan = snapshot.planName, !plan.isEmpty {
                        Text(plan).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                            .accessibilityLabel("\(plan) plan")
                    }
                }
                if let identity = identityLine(account) {
                    Text(identity).font(.callout).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    AccountStatusLine(status: .make(snapshot: snapshot, deletionPending: account.deletionPending,
                                                    refreshed: store.refreshAccountIDs.contains(account.id),
                                                    refreshing: store.refreshingAccounts.contains(account.id),
                                                    now: context.date))
                }
            }
            Spacer()
            if snapshot.requiresLogin && !account.deletionPending {
                Button("Reconnect") { store.startLogin(account.provider, replacing: account) }
                    .controlSize(.small)
                    .disabled(store.isLoggingIn || store.pendingLogin != nil || store.storageUnavailable)
            }
            Menu {
                Button("Rename") { editing = account }
                    .disabled(account.deletionPending || store.storageUnavailable)
                Button("Reconnect") { store.startLogin(account.provider, replacing: account) }
                    .disabled(store.isLoggingIn || store.pendingLogin != nil || account.deletionPending || store.storageUnavailable)
                Button("Delete", role: .destructive) { deleting = account }
                    .disabled(store.isLoggingIn || store.pendingLogin != nil || store.storageUnavailable)
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Account options")
        }
    }

    /// Email and organization on one line. The provider shows in the mark.
    private func identityLine(_ account: UsageAccount) -> String? {
        let parts = [account.identity?.email, account.identity?.visibleOrganization].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " · ") }
        return account.isManaged ? "Account details unavailable" : nil
    }

    @ViewBuilder private var accountDragOverlay: some View {
        if let drag = accountDrag, let account = store.orderedAccounts.first(where: { $0.id == drag.source }) {
            DragSlotPlaceholder(cornerRadius: 10)
                .frame(width: drag.placeholder.width, height: drag.placeholder.height)
                .offset(x: drag.placeholder.minX, y: drag.placeholder.minY)
                .animation(.snappy(duration: 0.18), value: drag.target)
            SettingsRow { row(account, preview: true) }
                .frame(width: drag.floatingFrame.width, height: drag.floatingFrame.height)
                .modifier(FloatingDragCard(settling: settlingAccountDrag, liftScale: 1.02, cornerRadius: 10))
                .offset(x: drag.floatingFrame.minX, y: drag.floatingFrame.minY)
        }
    }

    private func updateAccountDrag(_ id: UUID, value: DragGesture.Value) {
        guard !settlingAccountDrag else { return }
        if accountDrag == nil {
            accountDrag = ReorderDragPreview(source: id, order: store.orderedAccounts.map(\.id), frames: accountFrames,
                                             location: value.location, translation: value.translation,
                                             hitPadding: CGSize(width: 3, height: 6))
        } else {
            accountDrag?.location = value.location
            accountDrag?.translation = value.translation
        }
    }

    private func finishAccountDrag(at point: CGPoint) {
        guard var drag = accountDrag, !settlingAccountDrag else { return }
        drag.location = point
        let target = drag.target
        accountDrag = drag
        withAnimation(.easeOut(duration: 0.16)) {
            settlingAccountDrag = true
            accountDrag?.translation = drag.landingTranslation
        } completion: {
            guard accountDrag?.source == drag.source else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let target, store.orderedAccounts.map(\.id) == drag.order { store.moveAccount(drag.source, to: target) }
                accountDrag = nil
                settlingAccountDrag = false
            }
        }
    }

    private func moveAccount(_ id: UUID, offset: Int) {
        let order = store.orderedAccounts.map(\.id)
        guard let index = order.firstIndex(of: id), order.indices.contains(index + offset) else { return }
        store.moveAccount(id, to: order[index + offset])
    }
}

/// A colored dot and a short line: updated, waiting, or what needs attention.
private struct AccountStatusLine: View {
    let status: AccountCardStatus
    var body: some View {
        let line = HStack(spacing: 5) {
            Circle().fill(dotColor).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(status.text).font(.caption).lineLimit(1)
                .foregroundStyle(status.tone == .attention ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        }
        if let detail = status.detail { line.help(detail) } else { line }
    }
    private var dotColor: Color {
        switch status.tone {
        case .ok: return .green
        case .attention: return .orange
        case .quiet: return Color.secondary.opacity(0.5)
        }
    }
}

private struct AddAccountProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let select: (ProviderKind) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Account").font(.title3.bold())
                Text("Sign in using your usual browser. AgentBar keeps a separate sign-in for usage monitoring.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ProviderKind.allCases) { provider in
                Button {
                    dismiss()
                    select(provider)
                } label: {
                    HStack(spacing: 12) {
                        ProviderMark(provider: provider)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName).font(.headline)
                            Text(provider.accountSummary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(ChoiceButtonStyle(selected: false))
                .accessibilityLabel("Add \(provider.displayName) account")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 390)
    }
}

// Sign-in states. The identity checks stay; only the button labels are unified.
struct LoginProgressView: View {
    @EnvironmentObject private var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isLoggingIn { ProgressView().controlSize(.small) }
            Text(store.loginMessage ?? "")
            if store.canOpenPrivateLogin {
                Button("Use Private Window Instead") { store.openPrivateLogin() }
            }
            if let pending = store.pendingLogin {
                if let identity = pending.account.identity?.description, !identity.isEmpty {
                    Text(verbatim: identity).font(.headline).textSelection(.enabled)
                } else {
                    Text("The provider did not return account details.").font(.headline)
                }
                if pending.replacing != nil {
                    if store.reconnectionComparison == .different {
                        Text("This is a different account from the one being reconnected. It can only be added as a new account.")
                        Button("Add Account") { store.confirmLogin(addAsNew: true) }.keyboardShortcut(.defaultAction)
                            .disabled(!store.canAddAccount)
                    } else if store.reconnectionComparison != .same {
                        Text("The account identity could not be verified automatically. Reconnect only if this is the same account.")
                        HStack {
                            Button("Reconnect") { store.confirmLogin(replaceUnverified: true) }.keyboardShortcut(.defaultAction)
                            Button("Add Account") { store.confirmLogin(addAsNew: true) }.disabled(!store.canAddAccount)
                        }
                    } else { Button("Reconnect") { store.confirmLogin() }.keyboardShortcut(.defaultAction) }
                } else { Button("Add Account") { store.confirmLogin() }.keyboardShortcut(.defaultAction) }
            }
            Button("Cancel", role: .cancel) { store.cancelLogin() }.keyboardShortcut(.cancelAction)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.08)))
    }
}

struct AccountEditSheet: View {
    let account: UsageAccount
    @EnvironmentObject private var store: UsageStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    init(account: UsageAccount, displayName: String) {
        self.account = account
        _name = State(initialValue: displayName)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Account").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(account.provider.displayName).font(.subheadline)
                if let identity = account.identity?.description, !identity.isEmpty {
                    Text(identity).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            TextField("Account name", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("Badge text and color are edited on usage lines in Menu Bar.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    store.rename(account, name: name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 380)
    }
}
