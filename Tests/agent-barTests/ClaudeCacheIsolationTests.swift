import Foundation
import Testing
@testable import agent_bar

struct ClaudeCacheIsolationTests {
    @Test func cooldownWithoutGoodValueAndCredentialChange() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-cache-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ClaudeUsageCache(overrideURL: directory.appendingPathComponent("usage.json"), enabled: true)
        let now = Date()
        let failure = RemoteUsageData(planName: nil, fiveHourUsedPercent: nil, weeklyUsedPercent: nil,
            fiveHourResetAt: nil, weeklyResetAt: nil, modelWeeklies: nil, apiUnavailable: true,
            apiError: "rate-limited", usageSource: .oauthApi, weeklyWindowLabel: nil)
        try cache.write(data: failure, timestamp: now, credentialCacheKey: "account-A", rateLimitedCount: 1,
                        retryAfterUntil: now.addingTimeInterval(120))
        cache.expire()
        let limited = try cache.readState(now: now.addingTimeInterval(65), credentialCacheKey: "account-A")
        #expect(limited.isFresh)
        #expect(limited.data.weeklyUsedPercent == nil)
        #expect(try !cache.readState(now: now.addingTimeInterval(65), credentialCacheKey: "account-B").isFresh)
        #expect(try !cache.readState(now: now.addingTimeInterval(65), credentialCacheKey: nil).isFresh)
        #expect(cache.makeLastGoodState(from: try cache.readRaw(), credentialCacheKey: "account-B") == nil)
    }
    @Test func lastGoodValueRequiresMatchingCredential() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-cache-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ClaudeUsageCache(overrideURL: directory.appendingPathComponent("usage.json"), enabled: true)
        let good = RemoteUsageData(planName: "Pro", fiveHourUsedPercent: 25, weeklyUsedPercent: 40,
            fiveHourResetAt: nil, weeklyResetAt: nil, modelWeeklies: nil, apiUnavailable: false,
            apiError: nil, usageSource: .oauthApi, weeklyWindowLabel: nil)
        try cache.write(data: good, timestamp: .now, credentialCacheKey: "account-A", lastGoodData: good)
        let raw = try cache.readRaw()
        #expect(cache.makeLastGoodState(from: raw, credentialCacheKey: "account-A")?.data.weeklyUsedPercent == 40)
        #expect(cache.makeLastGoodState(from: raw, credentialCacheKey: "account-B") == nil)
        #expect(cache.makeLastGoodState(from: raw, credentialCacheKey: nil) == nil)
    }

    @Test func expiringUsageKeepsTheLastSuccessfulUpdateTime() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-cache-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ClaudeUsageCache(overrideURL: directory.appendingPathComponent("usage.json"), enabled: true)
        let lastUpdated = Date(timeIntervalSince1970: 1_800_000_000)
        let now = lastUpdated.addingTimeInterval(10)
        let good = RemoteUsageData(planName: "Pro", fiveHourUsedPercent: 25, weeklyUsedPercent: 40,
            fiveHourResetAt: nil, weeklyResetAt: nil, modelWeeklies: nil, apiUnavailable: false,
            apiError: nil, usageSource: .oauthApi, weeklyWindowLabel: nil)
        try cache.write(data: good, timestamp: lastUpdated, credentialCacheKey: "account-A",
                        lastGoodData: good, lastGoodTimestamp: lastUpdated)
        #expect(try cache.readState(now: now, credentialCacheKey: "account-A").isFresh)

        cache.expire()

        let forced = try cache.readState(now: now, credentialCacheKey: "account-A")
        #expect(!forced.isFresh && forced.updatedAt == lastUpdated)
        let fallback = cache.makeLastGoodState(from: try cache.readRaw(), credentialCacheKey: "account-A")
        #expect(fallback?.data.weeklyUsedPercent == 40 && fallback?.updatedAt == lastUpdated)
    }

    @Test func legacyExpiryMarkerUsesThePreservedLastGoodTime() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-cache-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ClaudeUsageCache(overrideURL: directory.appendingPathComponent("usage.json"), enabled: true)
        let lastUpdated = Date(timeIntervalSince1970: 1_800_000_000)
        let good = RemoteUsageData(planName: "Pro", fiveHourUsedPercent: 25, weeklyUsedPercent: 40,
            fiveHourResetAt: nil, weeklyResetAt: nil, modelWeeklies: nil, apiUnavailable: false,
            apiError: nil, usageSource: .oauthApi, weeklyWindowLabel: nil)
        try cache.write(data: good, timestamp: Date(timeIntervalSince1970: 0), credentialCacheKey: "account-A",
                        lastGoodData: good, lastGoodTimestamp: lastUpdated)

        let fallback = cache.makeLastGoodState(from: try cache.readRaw(), credentialCacheKey: "account-A")
        #expect(fallback?.updatedAt == lastUpdated)
    }

    @Test func legacyRateLimitFallbackUsesTheSuccessfulAccountSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-cache-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ClaudeUsageCache(overrideURL: directory.appendingPathComponent("usage.json"), enabled: true)
        let updated = Date(timeIntervalSince1970: 1_800_000_000)
        let failedAt = updated.addingTimeInterval(60)
        let good = RemoteUsageData(planName: "Pro", fiveHourUsedPercent: 25, weeklyUsedPercent: 40,
            fiveHourResetAt: nil, weeklyResetAt: nil, modelWeeklies: nil, apiUnavailable: false,
            apiError: nil, usageSource: .oauthApi, weeklyWindowLabel: nil)
        let failed = good.with(apiUnavailable: true, apiError: "rate-limited")
        try cache.write(data: failed, timestamp: failedAt, credentialCacheKey: "account-A", rateLimitedCount: 1,
                        lastGoodData: good, lastGoodTimestamp: Date(timeIntervalSince1970: 0))
        let window = WindowSummary(tokens: 40, limitTokens: 100, resetAt: nil, displayStyle: .percentage)
        let snapshot = ProviderSnapshot(provider: .claude, updatedAt: updated, fiveHour: nil, weekly: window,
            modelWeeklies: [], planName: "Pro", sourceDescription: "", note: nil, isStale: false, requiresLogin: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: directory.appendingPathComponent("last-good.json"))

        let limited = try cache.readState(now: failedAt.addingTimeInterval(15), credentialCacheKey: "account-A")
        #expect(limited.isFresh && limited.data.apiUnavailable && limited.updatedAt == updated)
        let raw = try cache.readRaw()
        #expect(cache.makeLastGoodState(from: raw, credentialCacheKey: "account-A")?.updatedAt == updated)
        #expect(cache.makeLastGoodState(from: raw, credentialCacheKey: "account-B") == nil)
    }
}
