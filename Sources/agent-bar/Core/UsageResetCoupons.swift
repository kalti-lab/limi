import Foundation

// An account's usage-reset coupons, as the service reported them with its usage. Codex reads them from
// `account/rateLimits/read` (`rateLimitResetCredits`) and uses one with `account/rateLimitResetCredit/consume`; Claude
// reads them from `/api/oauth/usage?cedar_ember=1` and uses one with `POST /api/organizations/{org}/reset_rate_limits`.
struct UsageResetCoupons: Equatable, Codable, Sendable {
    // What one coupon clears.
    enum Scope: String, Equatable, Codable, Sendable {
        // Codex's "Full reset (Weekly + 5 hr)" and Claude's full grants.
        case fiveHourAndWeekly
        // Claude's session grants.
        case fiveHour
        // Claude's weekly grants.
        case weekly
    }

    // What is sent when one is used.
    enum Claim: Equatable, Codable, Sendable {
        // The credit that expires first, or none to let the service choose.
        case codex(creditID: String?)
        // A granted reset ("cedar_ember").
        case claudeGrant(grantID: String)
    }

    var count: Int
    var scope: Scope
    // When each coupon expires, where the service says.
    var expiries: [Date] = []
    var claim: Claim

    // A coupon that can be used now.
    var usable: UsageResetCoupons? { count > 0 ? self : nil }

    // The same coupons after one was used.
    func usingOne() -> UsageResetCoupons? {
        guard count > 1 else { return nil }
        var next = self
        next.count -= 1
        if !next.expiries.isEmpty { next.expiries.removeFirst(min(1, next.expiries.count)) }
        return next
    }
}

// How using a coupon ended.
enum CouponOutcome: Equatable, Sendable {
    // The limits are cleared.
    case reset
    // Not at a limit: nothing was reset and the coupon was not used.
    case nothingToReset
    // The service has no coupon for the account any more (used elsewhere, expired).
    case noCoupon
    // The sign-in is not accepted.
    case signInAgain
    // Too many requests, no connection, or an answer that could not be read.
    case tryLater
}

// Codex's coupons, from the usage answer it already gives.
enum CodexResetCredits {
    struct Summary: Decodable {
        let availableCount: Int?
        let credits: [Credit]?
    }

    struct Credit: Decodable {
        let id: String
        let status: String?
        let resetType: String?
        let expiresAt: Int64?
    }

    // Nil when the account has none, or when an older codex does not report them.
    static func coupons(from result: [String: Any], now: Date = .now) -> UsageResetCoupons? {
        guard let raw = result["rateLimitResetCredits"], !(raw is NSNull),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let summary = try? JSONDecoder().decode(Summary.self, from: data) else { return nil }
        return coupons(summary, now: now)
    }

    static func coupons(_ summary: Summary, now: Date = .now) -> UsageResetCoupons? {
        let count = summary.availableCount ?? 0
        guard count > 0 else { return nil }
        // Only coupons that can still be used; the list may be cut short, so the count comes from `availableCount`.
        let available = (summary.credits ?? []).filter { $0.status == "available" }
            .map { (id: $0.id, expires: $0.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }) }
            .filter { $0.expires.map { $0 > now } ?? true }
        let first = available.min { ($0.expires ?? .distantFuture) < ($1.expires ?? .distantFuture) }
        return UsageResetCoupons(count: count, scope: .fiveHourAndWeekly,
                                 expiries: available.compactMap(\.expires).sorted(),
                                 claim: .codex(creditID: first?.id))
    }

    // The answer to `account/rateLimitResetCredit/consume`.
    static func outcome(_ result: [String: Any]) -> CouponOutcome {
        switch result["outcome"] as? String {
        case "reset": .reset
        // The same attempt already went through: it was reset. A fresh key is sent each time, so this is a retry.
        case "alreadyRedeemed": .reset
        case "nothingToReset": .nothingToReset
        case "noCredit": .noCoupon
        default: .tryLater
        }
    }
}
