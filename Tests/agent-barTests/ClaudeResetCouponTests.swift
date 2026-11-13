import Foundation
import Testing
@testable import agent_bar

// Claude's coupons ("cedar_ember" grants): which grants count, how often they are read, and what a claim sends and how
// its answer is read. A fake transport stands in for the service.
@Suite(.serialized)
struct ClaudeResetCouponTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static func at(_ days: Double) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(days * 86_400))
    }

    private static func body(eligible: Bool = true, reason: String? = nil, atLimit: Bool = false, exhausted: [String] = [],
                             grants: [[String: Any]]) -> Data {
        let block: [String: Any] = ["eligible": eligible, "ineligible_reason": reason ?? NSNull(), "at_limit": atLimit,
                                    "exhausted": exhausted, "grants": grants]
        return try! JSONSerialization.data(withJSONObject: ["five_hour": ["utilization": 40], "cedar_ember": block])
    }

    @Test func grantsCountWhenUsableAndTheFirstToEndIsUsed() throws {
        let data = Self.body(grants: [
            ["id": "full_b", "resets_left": 2, "ends_at": Self.at(20), "clears": ["five_hour", "seven_day"]],
            ["id": "full_a", "resets_left": 1, "ends_at": Self.at(10), "type": "full"],
            ["id": "paused", "resets_left": 4, "ends_at": Self.at(5), "type": "full", "paused": true],
            ["id": "ended", "resets_left": 1, "ends_at": Self.at(-1), "type": "full"],
            ["id": "fable", "resets_left": 1, "ends_at": Self.at(2), "gives_back_weekly": true],
            ["id": "BAD ID", "resets_left": 1, "ends_at": Self.at(1), "type": "full"],
        ])
        let coupons = try #require(ClaudeCedar.block(from: data).flatMap { ClaudeCedar.coupons($0, now: Self.now) })
        #expect(coupons.claim == .claudeGrant(grantID: "full_a"))
        #expect(coupons.count == 3 && coupons.scope == .fiveHourAndWeekly)
        #expect(coupons.expiries.count == 3 && coupons.expiries.first == ClaudeCedar.date(Self.at(10)))
    }

    @Test func kindsFollowClaudeCode() throws {
        func scope(_ grant: [String: Any]) -> UsageResetCoupons.Scope? {
            var grant = grant; grant["id"] = "g"; grant["resets_left"] = 1
            return ClaudeCedar.block(from: Self.body(grants: [grant])).flatMap { ClaudeCedar.coupons($0, now: Self.now) }?.scope
        }
        #expect(scope(["type": "session"]) == .fiveHour)
        #expect(scope(["clears": ["five_hour"]]) == .fiveHour)
        #expect(scope(["type": "weekly"]) == .weekly)
        #expect(scope(["clears": ["seven_day"]]) == .weekly)
        #expect(scope(["clears": ["five_hour", "seven_day"]]) == .fiveHourAndWeekly)
        #expect(scope(["type": "full", "gives_back_weekly": true]) == nil)
    }

    @Test func atALimitAGrantThatClearsItGoesFirst() throws {
        let data = Self.body(atLimit: true, exhausted: ["seven_day"], grants: [
            ["id": "session", "resets_left": 1, "ends_at": Self.at(1), "type": "session", "clears": ["five_hour"]],
            ["id": "weekly", "resets_left": 1, "ends_at": Self.at(9), "type": "weekly", "clears": ["seven_day"]],
        ])
        let coupons = try #require(ClaudeCedar.block(from: data).flatMap { ClaudeCedar.coupons($0, now: Self.now) })
        #expect(coupons.claim == .claudeGrant(grantID: "weekly") && coupons.scope == .weekly && coupons.count == 1)
    }

    @Test func ineligibleAccountsHaveNone() {
        let data = Self.body(eligible: false, reason: "surface", grants: [])
        #expect(ClaudeCedar.block(from: data).flatMap { ClaudeCedar.coupons($0, now: Self.now) } == nil)
        #expect(ClaudeCedar.block(from: Data("{\"five_hour\":{}}".utf8)) == nil)
    }

    @Test func claimAnswers() {
        func outcome(_ result: String) -> (CouponOutcome, Bool) {
            let answer = ClaudeCedar.outcome(Data("{\"result\":\"\(result)\"}".utf8)); return (answer.outcome, answer.unconfirmed)
        }
        #expect(outcome("reset") == (.reset, false))
        #expect(outcome("not_limited") == (.nothingToReset, false))
        #expect(outcome("already_used") == (.noCoupon, false))
        #expect(outcome("ineligible") == (.noCoupon, false))
        #expect(outcome("cooldown") == (.tryLater, false))
        #expect(outcome("unavailable") == (.tryLater, true))
        #expect(outcome("brand_new") == (.tryLater, true))
    }

    @Test func couponsAreReadEveryHalfHourAndRarelyWhenTheAccountCannotHaveAny() async throws {
        let fixture = try ClaudeFixture()
        defer { fixture.close() }
        fixture.transport.answer = (200, Self.body(grants: [["id": "g", "resets_left": 2, "ends_at": Self.at(9), "type": "full"]]))
        let first = await fixture.provider.readCoupons(accessToken: "tok", now: Self.now)
        #expect(first?.count == 2)
        #expect(fixture.transport.requests.map { $0.url } == [ClaudeCedar.readURL])
        #expect(fixture.transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        // Within the half hour the file answers.
        #expect(await fixture.provider.readCoupons(accessToken: "tok", now: Self.now.addingTimeInterval(29 * 60))?.count == 2)
        #expect(fixture.transport.requests.count == 1)
        // A refused read keeps what was known.
        fixture.transport.answer = (429, Data())
        #expect(await fixture.provider.readCoupons(accessToken: "tok", now: Self.now.addingTimeInterval(31 * 60))?.count == 2)
        #expect(fixture.transport.requests.count == 2)
        // An account that cannot have coupons is asked again only after six hours.
        fixture.transport.answer = (200, Self.body(eligible: false, reason: "surface", grants: []))
        let later = Self.now.addingTimeInterval(40 * 60)
        #expect(await fixture.provider.readCoupons(accessToken: "tok", now: later) == nil)
        _ = await fixture.provider.readCoupons(accessToken: "tok", now: later.addingTimeInterval(5 * 3600))
        #expect(fixture.transport.requests.count == 3)
        _ = await fixture.provider.readCoupons(accessToken: "tok", now: later.addingTimeInterval(6 * 3600 + 1))
        #expect(fixture.transport.requests.count == 4)
    }

    @Test func aClaimPostsTheGrantToTheAccountsOrganizationAndReusesAnUnconfirmedRequestID() async throws {
        let fixture = try ClaudeFixture()
        defer { fixture.close() }
        let coupons = UsageResetCoupons(count: 1, scope: .fiveHourAndWeekly, claim: .claudeGrant(grantID: "grant_1"))
        fixture.transport.answer = (200, Data("{\"result\":\"reset\",\"resets_left\":0}".utf8))
        #expect(await fixture.provider.useCoupon(coupons) == .reset)
        let request = try #require(fixture.transport.requests.last)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.anthropic.com/api/organizations/0f1e2d3c-org/reset_rate_limits")
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
        #expect(body["program"] == "cedar_ember" && body["grant_id"] == "grant_1")
        let firstID = try #require(body["request_id"])

        // Not sure it went through: the next press sends the same request id.
        fixture.transport.answer = (503, Data())
        #expect(await fixture.provider.useCoupon(coupons) == .tryLater)
        let unsure = try fixture.transport.lastBody()["request_id"]
        #expect(unsure != firstID)
        fixture.transport.answer = (200, Data("{\"result\":\"not_limited\"}".utf8))
        #expect(await fixture.provider.useCoupon(coupons) == .nothingToReset)
        #expect(try fixture.transport.lastBody()["request_id"] == unsure)

        fixture.transport.answer = (401, Data())
        #expect(await fixture.provider.useCoupon(coupons) == .signInAgain)
        fixture.transport.answer = (429, Data())
        #expect(await fixture.provider.useCoupon(coupons) == .tryLater)
    }
}

// An account folder with a sign-in that has not expired, its organization, and a fake transport.
private struct ClaudeFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("coupon-claude-\(UUID())")
    let transport = FakeTransport()
    var provider: ClaudeUsageProvider {
        let transport = transport
        return ClaudeUsageProvider(directory: root, cacheURL: root.appendingPathComponent("cache/usage.json"),
                                   transport: { try transport.send($0) })
    }

    init() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let expires = Int(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        try Data("{\"claudeAiOauth\":{\"accessToken\":\"tok\",\"expiresAt\":\(expires),\"subscriptionType\":\"max\"}}".utf8)
            .write(to: root.appendingPathComponent(".credentials.json"))
        try Data("{\"oauthAccount\":{\"emailAddress\":\"cl@example.test\",\"organizationUuid\":\"0f1e2d3c-org\"}}".utf8)
            .write(to: root.appendingPathComponent(".claude.json"))
    }

    func close() { try? FileManager.default.removeItem(at: root) }
}

private final class FakeTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [URLRequest] = []
    private var reply: (Int, Data) = (200, Data())
    var answer: (Int, Data) {
        get { lock.lock(); defer { lock.unlock() }; return reply }
        set { lock.lock(); reply = newValue; lock.unlock() }
    }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return sent }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        lock.lock(); defer { lock.unlock() }
        sent.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.0, httpVersion: nil, headerFields: nil)!
        return (reply.1, response)
    }

    func lastBody() throws -> [String: String] {
        try #require(JSONSerialization.jsonObject(with: requests.last?.httpBody ?? Data()) as? [String: String])
    }
}
