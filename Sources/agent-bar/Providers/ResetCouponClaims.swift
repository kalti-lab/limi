import Foundation

// Using one usage-reset coupon. Only a person's confirmed press calls these; a refresh never does.
enum CodexCouponClaim {
    // Uses the coupon in `coupons.claim` through the account's own app-server. `idempotencyKey` names this one attempt.
    static func use(_ coupons: UsageResetCoupons, directory: URL, expectedIdentity: AccountIdentity?,
                    idempotencyKey: String = UUID().uuidString, control: OperationControl = OperationControl(),
                    executable: URL? = nil, environment: [String: String]? = nil) async -> CouponOutcome {
        guard case .codex(let creditID) = coupons.claim else { return .tryLater }
        return await Task.detached(priority: .userInitiated) {
            do {
                let rpc = try CodexRPC(directory: directory, control: control, executable: executable, environment: environment)
                defer { rpc.stop() }
                let identity = try rpc.identity()
                if let expectedIdentity, identity.comparison(to: expectedIdentity) == .different { return .signInAgain }
                var params: [String: Any] = ["idempotencyKey": idempotencyKey]
                if let creditID { params["creditId"] = creditID }
                let result = try rpc.request("account/rateLimitResetCredit/consume", params: params)
                return CodexResetCredits.outcome(result)
            } catch AccountError.loginRequired {
                return .signInAgain
            } catch {
                return .tryLater
            }
        }.value
    }
}
