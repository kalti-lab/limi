import Foundation

// Claude's usage-reset coupons ("cedar_ember" grants). Undocumented; the names follow Claude Code 2.1.323, which reads
// them from `/api/oauth/usage?cedar_ember=1&skip_spend=1` and uses one with
// `POST /api/organizations/{org}/reset_rate_limits {"program":"cedar_ember","grant_id","request_id"}`.
// The 5-hour reset ("juniper_tide") is left out: it is not a coupon but a weekly allowance, read only at a limit.
enum ClaudeCedar {
    static let readURL = URL(string: "https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1")!
    static func claimURL(organization: String) -> URL? {
        guard organization.range(of: "^[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://api.anthropic.com/api/organizations/\(organization)/reset_rate_limits")
    }

    struct Response: Decodable { let cedarEmber: Block? }

    struct Block: Decodable {
        let eligible: Bool?
        let ineligibleReason: String?
        let atLimit: Bool?
        let exhausted: [String]?
        let grants: [Grant]?
    }

    struct Grant: Decodable {
        let id: String?
        let resetsLeft: Int?
        let endsAt: String?
        let clears: [String]?
        let paused: Bool?
        let type: String?
        let givesBackWeekly: Bool?
    }

    enum Kind: Equatable { case session, weekly, full, fable }

    // As Claude Code names a grant: what it gives back, else its type, else what it clears.
    static func kind(_ grant: Grant) -> Kind {
        if grant.givesBackWeekly == true { return .fable }
        switch grant.type {
        case "session": return .session
        case "weekly": return .weekly
        case "full": return .full
        default: break
        }
        let clears = Set(grant.clears ?? [])
        if clears == ["five_hour"] { return .session }
        if !clears.contains("five_hour") && !clears.isEmpty { return .weekly }
        return .full
    }

    static func block(from data: Data) -> Block? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode(Response.self, from: data))?.cedarEmber
    }

    // The coupons an account can use now: grants that are not paused, have resets left and have not ended. Fable
    // grants are left out. Of several kinds, the one whose grant ends first is shown, and that kind's count.
    static func coupons(_ block: Block, now: Date = .now) -> UsageResetCoupons? {
        guard block.eligible == true else { return nil }
        let usable = (block.grants ?? []).compactMap { grant -> (grant: Grant, id: String, left: Int, ends: Date?)? in
            guard let id = grant.id, id.range(of: "^[a-z0-9_-]{1,40}$", options: .regularExpression) != nil,
                  let left = grant.resetsLeft, left > 0, grant.paused != true, kind(grant) != .fable else { return nil }
            let ends = grant.endsAt.flatMap(date)
            if let ends, ends <= now { return nil }
            return (grant, id, left, ends)
        }
        // At a limit, a grant that clears it.
        let exhausted = Set(block.exhausted ?? [])
        let clearing = block.atLimit == true && !exhausted.isEmpty
            ? usable.filter { !exhausted.isDisjoint(with: $0.grant.clears ?? []) } : []
        let candidates = clearing.isEmpty ? usable : clearing
        guard let first = candidates.min(by: { ($0.ends ?? .distantFuture) < ($1.ends ?? .distantFuture) }) else { return nil }
        let chosenKind = kind(first.grant)
        let same = usable.filter { kind($0.grant) == chosenKind }
        let scope: UsageResetCoupons.Scope = switch chosenKind {
        case .session: .fiveHour
        case .weekly: .weekly
        case .full, .fable: .fiveHourAndWeekly
        }
        return UsageResetCoupons(count: same.reduce(0) { $0 + $1.left }, scope: scope,
                                 expiries: same.flatMap { item in item.ends.map { Array(repeating: $0, count: item.left) } ?? [] }.sorted(),
                                 claim: .claudeGrant(grantID: first.id))
    }

    // The answer to a claim.
    static func outcome(_ data: Data) -> (outcome: CouponOutcome, unconfirmed: Bool) {
        let result = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["result"] as? String
        switch result {
        case "reset": return (.reset, false)
        case "not_limited": return (.nothingToReset, false)
        case "already_used", "ineligible": return (.noCoupon, false)
        case "cooldown": return (.tryLater, false)
        // "unavailable" or an unknown answer: it may have gone through.
        default: return (.tryLater, true)
        }
    }

    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

// What an account's coupons were and when the usage read should ask for them again: after 30 minutes, after 6 hours while
// the account cannot have any, after 5 minutes when the service could not say.
struct ClaudeCouponRecord: Codable, Equatable {
    var coupons: UsageResetCoupons?
    var nextCheck: Date

    static let interval: TimeInterval = 30 * 60
    static let ineligibleInterval: TimeInterval = 6 * 60 * 60
    static let failureInterval: TimeInterval = 5 * 60

    static func url(nextTo usageCache: URL) -> URL {
        usageCache.deletingLastPathComponent().appendingPathComponent("claude-coupons.json")
    }
}

// A claim whose answer did not say whether it went through. Pressing again within 10 minutes sends the same request id,
// so the service does not use a second coupon.
actor ClaudeClaimMemory {
    static let shared = ClaudeClaimMemory()
    private var pending: [String: (id: String, at: Date)] = [:]

    func requestID(for grant: String, now: Date = .now) -> String {
        if let held = pending[grant], now.timeIntervalSince(held.at) < 600 { return held.id }
        return UUID().uuidString
    }
    func remember(_ id: String, for grant: String, now: Date = .now) { pending[grant] = (id, now) }
    func forget(_ grant: String) { pending[grant] = nil }
}
