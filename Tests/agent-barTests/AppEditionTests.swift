import Foundation
import Testing
@testable import agent_bar

@MainActor
struct AppEditionTests {
    private let work = UsageAccount(id: UUID(), provider: .claude, name: "Work",
                                    identity: AccountIdentity(email: "work@example.com", stableID: "work"),
                                    credentialID: UUID())

    /// A store with the given accounts already registered, as on disk.
    private func store(_ edition: AppEdition, accounts: [UsageAccount]) throws -> (UsageStore, () -> Void) {
        let suite = "AppEditionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("edition-\(UUID())"))
        var registry = AccountRegistry(accounts: accounts); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        let store = UsageStore(settings: AppSettings(defaults: defaults), files: files, autoRefresh: false, edition: edition)
        return (store, {
            store.shutdown()
            try? FileManager.default.removeItem(at: files.root)
            defaults.removePersistentDomain(forName: suite)
        })
    }

    @Test func freeRegistersOneAccountAndProHasNoLimit() {
        #expect(AppEdition.free.accountLimit == 1 && !AppEdition.free.customizesMenuBar)
        #expect(AppEdition.pro.accountLimit == nil && AppEdition.pro.customizesMenuBar)
    }

    @Test func freeStopsASecondAccountBeforeAnySignInStarts() throws {
        let (free, close) = try store(.free, accounts: [work]); defer { close() }
        #expect(free.canAddAccount == false)
        // Refused before any CLI or browser is started.
        free.startLogin(.codex)
        #expect(!free.isLoggingIn && free.errorMessage == UsageStore.accountLimitMessage)
        #expect(free.accounts.count == 1)
    }

    @Test func freeStillTakesItsFirstAccountAndProTakesMore() throws {
        let (empty, closeEmpty) = try store(.free, accounts: []); defer { closeEmpty() }
        #expect(empty.canAddAccount)
        let (pro, closePro) = try store(.pro, accounts: [work]); defer { closePro() }
        #expect(pro.canAddAccount)
    }

    @Test func aDifferentAccountFromAReconnectCannotBeAddedPastTheLimit() throws {
        let (free, close) = try store(.free, accounts: [work]); defer { close() }
        let other = UsageAccount(id: UUID(), provider: .claude, name: "Other",
                                 identity: AccountIdentity(email: "other@example.com", stableID: "other"),
                                 credentialID: UUID())
        // Signing in while reconnecting Work returned another account.
        free.presentCompletedLogin(other, replacing: work.id)
        #expect(free.reconnectionComparison == .different)
        free.confirmLogin(addAsNew: true)
        #expect(free.errorMessage == UsageStore.accountLimitMessage)
        #expect(free.accounts.map(\.id) == [work.id])
    }
}

struct PurchaseLinkTests {
    @Test func onlyAnHTTPSPageIsUsed() {
        #expect(AppEdition.purchaseURL(from: " https://example.com/agentbar ")?.absoluteString == "https://example.com/agentbar")
        // No site yet, or one that is not https, leaves the link waiting.
        #expect(AppEdition.purchaseURL(from: nil) == nil)
        #expect(AppEdition.purchaseURL(from: "") == nil)
        #expect(AppEdition.purchaseURL(from: "http://example.com") == nil)
        #expect(AppEdition.purchaseURL(from: "javascript:alert(1)") == nil)
    }
}
