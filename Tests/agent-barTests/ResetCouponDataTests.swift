import Foundation
import Testing
@testable import agent_bar

// Reading and using usage-reset coupons. No test reaches a service: Codex is a fake app-server script, Claude a fake
// transport.
@Suite(.serialized)
struct ResetCouponDataTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static func day(_ days: Double) -> Int64 { Int64(now.timeIntervalSince1970 + days * 86_400) }

    // MARK: Codex

    @Test func codexCouponsCountAvailableCreditsAndUseTheOneThatExpiresFirst() throws {
        let result: [String: Any] = ["rateLimits": [:], "rateLimitResetCredits": ["availableCount": 3, "credits": [
            ["id": "late", "status": "available", "resetType": "codexRateLimits", "grantedAt": 1, "expiresAt": Self.day(30)],
            ["id": "first", "status": "available", "resetType": "codexRateLimits", "grantedAt": 1, "expiresAt": Self.day(18)],
            ["id": "used", "status": "redeemed", "resetType": "codexRateLimits", "grantedAt": 1, "expiresAt": Self.day(1)],
            ["id": "same", "status": "available", "resetType": "codexRateLimits", "grantedAt": 1, "expiresAt": Self.day(18)],
        ]]]
        let coupons = try #require(CodexResetCredits.coupons(from: result, now: Self.now))
        #expect(coupons.count == 3 && coupons.scope == .fiveHourAndWeekly)
        #expect(coupons.expiries.count == 3 && coupons.expiries.first == Date(timeIntervalSince1970: TimeInterval(Self.day(18))))
        #expect(coupons.claim == .codex(creditID: "first"))
        // One used: one fewer, and its day goes.
        #expect(coupons.usingOne()?.count == 2 && coupons.usingOne()?.expiries.count == 2)
    }

    @Test func codexWithoutDetailsOrCouponsOrTheFieldShowsWhatItKnows() {
        // Only the count: the service picks the credit.
        let counted = CodexResetCredits.coupons(from: ["rateLimitResetCredits": ["availableCount": 2, "credits": NSNull()]])
        #expect(counted?.count == 2 && counted?.claim == .codex(creditID: nil) && counted?.expiries.isEmpty == true)
        #expect(CodexResetCredits.coupons(from: ["rateLimitResetCredits": ["availableCount": 0, "credits": []]]) == nil)
        #expect(CodexResetCredits.coupons(from: ["rateLimitResetCredits": NSNull()]) == nil)
        // An older codex says nothing about coupons.
        #expect(CodexResetCredits.coupons(from: ["rateLimits": [:]]) == nil)
    }

    @Test func codexOutcomes() {
        #expect(CodexResetCredits.outcome(["outcome": "reset"]) == .reset)
        #expect(CodexResetCredits.outcome(["outcome": "alreadyRedeemed"]) == .reset)
        #expect(CodexResetCredits.outcome(["outcome": "nothingToReset"]) == .nothingToReset)
        #expect(CodexResetCredits.outcome(["outcome": "noCredit"]) == .noCoupon)
        #expect(CodexResetCredits.outcome(["outcome": "something new"]) == .tryLater)
    }

    @Test func codexConsumeSendsTheCreditAndAKeyAndReadsTheOutcome() async throws {
        let fixture = try CodexFixture()
        defer { fixture.close() }
        let coupons = UsageResetCoupons(count: 2, scope: .fiveHourAndWeekly, claim: .codex(creditID: "first"))
        var outcome = await fixture.use(coupons, outcome: "reset", key: "key-1")
        #expect(outcome == .reset)
        let sent = try fixture.sent()
        #expect(sent["creditId"] as? String == "first" && sent["idempotencyKey"] as? String == "key-1")
        outcome = await fixture.use(UsageResetCoupons(count: 1, scope: .fiveHourAndWeekly, claim: .codex(creditID: nil)),
                                    outcome: "nothingToReset", key: "key-2")
        #expect(outcome == .nothingToReset)
        #expect(try fixture.sent()["creditId"] == nil)
        #expect(await fixture.use(coupons, outcome: "noCredit", key: "key-3") == .noCoupon)
        #expect(await fixture.use(coupons, outcome: "error:401 unauthorized", key: "key-4") == .signInAgain)
        #expect(await fixture.use(coupons, outcome: "error:server fell over", key: "key-5") == .tryLater)
    }
}

// A fake `codex app-server`: it answers initialize and account/read, writes what consume was sent to a file and answers
// with the outcome it is given, or with an error.
private struct CodexFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("coupon-codex-\(UUID())")
    var script: URL { root.appendingPathComponent("codex") }
    var log: URL { root.appendingPathComponent("sent.json") }

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let body = """
        #!/usr/bin/python3 -I
        import json, os, sys
        for line in sys.stdin:
            m = json.loads(line)
            if 'id' not in m: continue
            method, answer = m['method'], {'id': m['id']}
            if method == 'account/read':
                answer['result'] = {'account': {'type': 'chatgpt', 'email': 'cx@example.test', 'accountId': 'acct'}}
            elif method == 'account/rateLimitResetCredit/consume':
                open(os.environ['COUPON_LOG'], 'w').write(json.dumps(m['params']))
                outcome = os.environ['COUPON_OUTCOME']
                if outcome.startswith('error:'): answer['error'] = {'code': -1, 'message': outcome[6:]}
                else: answer['result'] = {'outcome': outcome}
            else:
                answer['result'] = {}
            print(json.dumps(answer), flush=True)
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    }

    func use(_ coupons: UsageResetCoupons, outcome: String, key: String) async -> CouponOutcome {
        let environment = ["PATH": "/usr/bin:/bin", "COUPON_LOG": log.path, "COUPON_OUTCOME": outcome]
        return await CodexCouponClaim.use(coupons, directory: root, expectedIdentity: AccountIdentity(email: "cx@example.test"),
                                          idempotencyKey: key, executable: script, environment: environment)
    }

    func sent() throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(contentsOf: log)) as? [String: Any])
    }

    func close() { try? FileManager.default.removeItem(at: root) }
}
