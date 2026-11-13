import AppKit
import Foundation
import SwiftUI
import Testing
@testable import agent_bar

// The coupon line: one line whatever it says, in English and Korean, and the store's way from "Reset" to how it ended.
@MainActor
@Suite(.serialized)
struct ResetCouponLineTests {
    // The words' room in a row of the panel's list: the list's and the row's side padding, the mark and its gap.
    static let column = GroupAccountListView.width - 12 - 16 - 26 - 10
    static let korean: Bundle = {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return Bundle(path: root.appendingPathComponent("assets").path)!
    }()
    // The longest each line gets: many coupons, a two-digit day, several going that day.
    static func coupons(_ scope: UsageResetCoupons.Scope = .fiveHourAndWeekly, count: Int = 12) -> UsageResetCoupons {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 13, hour: 12))!
        return UsageResetCoupons(count: count, scope: scope, expiries: count < 2 ? [] : [day, day] + Array(repeating: day.addingTimeInterval(86_400 * 9), count: count - 2),
                                 claim: .codex(creditID: "c"))
    }
    static var states: [(String, CouponPanel)] {
        var states: [(String, CouponPanel)] = []
        for scope in [UsageResetCoupons.Scope.fiveHourAndWeekly, .fiveHour, .weekly] {
            let coupons = coupons(scope)
            states += [("offer-\(scope)", CouponPanel(coupons: coupons, line: nil)),
                       ("confirm-\(scope)", CouponPanel(coupons: coupons, line: .confirmation)),
                       ("done-\(scope)", CouponPanel(coupons: coupons, line: .result(.reset, left: 11)))]
        }
        let coupons = coupons()
        states.append(("progress", CouponPanel(coupons: coupons, line: .progress)))
        for outcome in [CouponOutcome.nothingToReset, .noCoupon, .signInAgain, .tryLater] {
            states.append(("\(outcome)", CouponPanel(coupons: coupons, line: .result(outcome, left: nil))))
        }
        return states
    }

    @Test func everyStateIsOneLineOfTheSameHeightThatFitsInEnglishAndKorean() throws {
        #expect(CouponWords.question(.fiveHourAndWeekly, Self.korean).contains("쿠폰"))
        let button = NSHostingView(rootView: Button {} label: { Text(verbatim: "Reset").font(GroupAccountRow.buttonFont) }
            .buttonStyle(PanelBorderedButtonStyle()).fixedSize())
        #expect(button.fittingSize.height <= CouponLineView.height)
        for bundle in [Bundle.main, Self.korean] {
            for (name, panel) in Self.states {
                let line = CouponLineView(panel: panel, bundle: bundle)
                #expect(NSHostingView(rootView: line.frame(width: Self.column)).fittingSize.height == CouponLineView.height, "\(name)")
                // Its words at their whole width, never cut short.
                let whole = NSHostingView(rootView: line.fixedSize()).fittingSize.width
                #expect(whole <= Self.column, "\(name) \(bundle == .main ? "en" : "ko"): \(whole) > \(Self.column)")
            }
        }
    }

    @Test func aRowIsAsTallInEveryCouponStateAndAsBeforeWithoutCoupons() throws {
        func height(_ coupon: CouponPanel) -> CGFloat {
            let row = GroupAccountRow(provider: .codex, badge: "CX", address: "cx@example.test", snapshot: Self.snapshot(nil), coupon: coupon)
            return NSHostingView(rootView: row.frame(width: GroupAccountListView.width - 12)).fittingSize.height
        }
        let heights = Set(Self.states.map { height($0.1) })
        #expect(heights.count == 1)
        let without = height(.none)
        #expect(heights.first.map { $0 > without } == true)
        // No coupon left and nothing going on: the row is as it was.
        #expect(height(CouponPanel(coupons: Self.coupons(count: 0).usable, line: nil)) == without)
    }

    @Test func resetAsksThenUsesOneAndSaysHowItEndedForAWhile() async throws {
        let fixture = try CouponStoreFixture()
        defer { fixture.close() }
        await fixture.store.refresh()
        let store = fixture.store, account = fixture.codex
        #expect(store.couponPanel(for: account).coupons?.count == 3)
        #expect(!store.couponPanel(for: fixture.claude).shows)

        store.askToUseCoupon(account)
        #expect(store.couponPanel(for: account).line == .confirmation)
        store.cancelCoupon(account)
        #expect(store.couponPanel(for: account).line == nil)
        #expect(await fixture.service.calls == 0)

        await fixture.service.hold()
        store.askToUseCoupon(account)
        store.confirmCoupon(account)
        #expect(store.couponPanel(for: account).line == .progress)
        // A second OK while it runs does nothing.
        store.confirmCoupon(account)
        let loads = await fixture.loader.loads
        await fixture.loader.setCount(2)
        await fixture.service.release(.reset)
        try await fixture.waitFor { store.couponPanel(for: account).line == .result(.reset, left: 2) }
        #expect(await fixture.service.calls == 1)
        #expect(store.couponPanel(for: account).coupons?.count == 2)
        // Read again at once, then the line goes back to the coupons.
        try await fixture.waitFor { await fixture.loader.loads > loads }
        try await fixture.waitFor { store.couponPanel(for: account).line == nil }
        #expect(store.couponPanel(for: account).coupons?.count == 2)
    }

    @Test func noCouponLeftTakesTheLineAwayAndFailuresKeepTheCoupons() async throws {
        let fixture = try CouponStoreFixture()
        defer { fixture.close() }
        await fixture.store.refresh()
        let store = fixture.store, account = fixture.codex
        for outcome in [CouponOutcome.tryLater, .signInAgain, .nothingToReset] {
            await fixture.service.next(outcome)
            store.askToUseCoupon(account); store.confirmCoupon(account)
            try await fixture.waitFor { store.couponPanel(for: account).line == .result(outcome, left: nil) }
            #expect(store.couponPanel(for: account).coupons?.count == 3)
        }
        await fixture.service.next(.noCoupon)
        store.askToUseCoupon(account); store.confirmCoupon(account)
        try await fixture.waitFor { store.couponPanel(for: account).line == .result(.noCoupon, left: nil) }
        #expect(store.couponPanel(for: account).coupons == nil)
        try await fixture.waitFor { !store.couponPanel(for: account).shows }
    }

    nonisolated static func snapshot(_ coupons: UsageResetCoupons?, stale: Bool = false) -> ProviderSnapshot {
        var snapshot = ProviderSnapshot(provider: .codex, updatedAt: .now,
            fiveHour: WindowSummary(tokens: 64, limitTokens: 100, resetAt: .now.addingTimeInterval(3600), displayStyle: .percentage),
            weekly: WindowSummary(tokens: 22, limitTokens: 100, resetAt: .now.addingTimeInterval(86_400), displayStyle: .percentage),
            modelWeeklies: [], planName: "Team", sourceDescription: "Fixture", note: nil, isStale: stale, requiresLogin: false)
        snapshot.resetCoupons = coupons
        return snapshot
    }
}

@MainActor
private final class CouponStoreFixture {
    let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("coupon-store-\(UUID())"))
    let suite = "coupon-store-\(UUID())"
    let claude = UsageAccount(id: UUID(), provider: .claude, name: "A", credentialID: UUID())
    let codex = UsageAccount(id: UUID(), provider: .codex, name: "B", credentialID: UUID())
    let loader = CouponLoader()
    let service = CouponService()
    let store: UsageStore

    init() throws {
        var registry = AccountRegistry(accounts: [claude, codex]); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        try files.write(DisplayConfiguration.initial(registry), to: files.root.appendingPathComponent("display-v2.json"))
        let loader = loader, service = service, codexID = codex.id
        store = UsageStore(settings: AppSettings(defaults: UserDefaults(suiteName: suite)!), files: files, autoRefresh: false,
                           loadAccount: { account, _ in await loader.load(account, coupons: account.id == codexID) },
                           useCoupon: { _, _ in await service.use() }, couponResultSeconds: 0.3)
    }
    func close() { store.shutdown(); try? FileManager.default.removeItem(at: files.root); UserDefaults().removePersistentDomain(forName: suite) }
    func waitFor(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !(await condition()) {
            if Date() > deadline { throw AccountError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

private actor CouponLoader {
    private(set) var loads = 0
    private var count = 3
    func setCount(_ value: Int) { count = value }
    func load(_ account: UsageAccount, coupons: Bool) -> ProviderSnapshot {
        loads += 1
        return ResetCouponLineTests.snapshot(coupons ? UsageResetCoupons(count: count, scope: .fiveHourAndWeekly, claim: .codex(creditID: "c")) : nil)
    }
}

private actor CouponService {
    private(set) var calls = 0
    private var held = false
    private var outcome = CouponOutcome.reset
    func hold() { held = true }
    func next(_ value: CouponOutcome) { outcome = value }
    func release(_ value: CouponOutcome) { outcome = value; held = false }
    func use() async -> CouponOutcome {
        calls += 1
        while held { try? await Task.sleep(for: .milliseconds(5)) }
        return outcome
    }
}
