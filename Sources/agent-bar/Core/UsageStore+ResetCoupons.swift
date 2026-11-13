import Foundation

// Usage-reset coupons on a group's account list: "Reset" asks, OK uses one, and how it ended shows for a few seconds.
extension UsageStore {
    // What an account's row shows. Coupons come only with fresh usage, so cached or failed usage offers none.
    func couponPanel(for account: UsageAccount) -> CouponPanel {
        let snapshot = snapshot(for: account)
        let coupons = snapshot.isStale || snapshot.requiresLogin ? nil : snapshot.resetCoupons?.usable
        var line = couponLines[account.id]
        // The question has nothing to ask about once the coupons are gone.
        if line == .confirmation && coupons == nil { line = nil }
        return CouponPanel(coupons: coupons, line: line)
    }

    // "Reset": the line turns into the question.
    func askToUseCoupon(_ account: UsageAccount) {
        guard couponPanel(for: account).coupons != nil, couponLines[account.id] == nil || isResult(account.id) else { return }
        couponLines[account.id] = .confirmation
    }

    func cancelCoupon(_ account: UsageAccount) {
        guard couponLines[account.id] == .confirmation else { return }
        couponLines[account.id] = nil
    }

    // OK on the question: one coupon is used, then how it ended shows.
    func confirmCoupon(_ account: UsageAccount) {
        guard couponLines[account.id] == .confirmation, let coupons = couponPanel(for: account).coupons else { return }
        couponLines[account.id] = .progress
        Task { [weak self] in
            guard let self else { return }
            let outcome = await useCoupon(coupons, for: account)
            let left: Int? = outcome == .reset ? coupons.count - 1 : nil
            couponLines[account.id] = .result(outcome, left: left)
            applyCouponOutcome(outcome, coupons: coupons, for: account)
            let shown = couponLines[account.id]
            try? await Task.sleep(for: .seconds(couponResultSeconds))
            if couponLines[account.id] == shown { couponLines[account.id] = nil }
        }
    }

    private func isResult(_ id: UUID) -> Bool {
        if case .result = couponLines[id] { return true }
        return false
    }

    private func useCoupon(_ coupons: UsageResetCoupons, for account: UsageAccount) async -> CouponOutcome {
        if let useCouponOverride { return await useCouponOverride(account, coupons) }
        guard let directory = credentialDirectory(for: account) else { return .signInAgain }
        switch account.provider {
        case .codex:
            return await CodexCouponClaim.use(coupons, directory: directory, expectedIdentity: account.identity)
        case .claude:
            return await ClaudeUsageProvider(directory: directory, cacheURL: files.cache(account),
                                             expectedIdentity: account.identity).useCoupon(coupons)
        case .antigravity:
            return .tryLater
        }
    }
}
