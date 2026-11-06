import Foundation
import Testing
@testable import agent_bar

// Shapes follow open-source Antigravity quota monitors; nothing here reaches
// a real Antigravity or Google.
private let summary = #"""
{"response":{"groups":[
 {"displayName":"Gemini","buckets":[
   {"window":"5h","remainingFraction":0.75,"resetTime":"2026-11-06T18:00:00Z"},
   {"window":"weekly","remainingFraction":0.4,"resetTime":"2026-11-10T00:00:00.000Z"}]},
 {"displayName":"Claude/GPT","buckets":[
   {"window":"weekly","resetTime":"2026-11-10T00:00:00Z"},
   {"window":"5h","remainingFraction":0.1,"disabled":true}]}
]}}
"""#
private let status = #"{"userStatus":{"email":"someone@gmail.com","userTier":{"name":"Google AI Pro"}}}"#

struct AntigravityUsageProviderTests {
    @Test func theRunningAntigravityIsFoundByItsOwnCommandLine() {
        let ps = """
        /usr/bin/other-tool --hub-port=1111 --csrf_token=not-this-one
        /Applications/Antigravity.app/Contents/Resources/bin/language_server_macos_arm --hub-port=53412 --csrf_token=abc-123_X --verbose
        """
        #expect(AntigravityUsageProvider.endpoint(fromProcessList: ps) == .init(port: 53412, token: "abc-123_X"))
        #expect(AntigravityUsageProvider.endpoint(fromProcessList: "/Users/me/.local/bin/agy --hub-port=60000 --csrf_token=t0k")
            == .init(port: 60000, token: "t0k"))
        // No Antigravity, or one without both values: nothing to ask.
        #expect(AntigravityUsageProvider.endpoint(fromProcessList: "/usr/bin/other-tool --hub-port=1 --csrf_token=x") == nil)
        #expect(AntigravityUsageProvider.endpoint(fromProcessList: "/Applications/Antigravity.app/x --hub-port=53412") == nil)
    }

    @Test func eachModelGroupKeepsItsOwnFiveHourAndWeeklyLimits() throws {
        let groups = try AntigravityUsageProvider.groups(fromQuotaSummary: Data(summary.utf8))
        #expect(groups.map(\.label) == ["Gemini", "Claude/GPT"])
        #expect(groups[0].fiveHour?.utilization == 0.25 && groups[0].weekly?.utilization == 0.6)
        #expect(groups[0].weekly?.resetAt == ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z"))
        // A missing fraction means nothing used; a disabled limit is left out.
        #expect(groups[1].weekly?.utilization == 0 && groups[1].fiveHour == nil)
    }

    @Test func theAccountAndPlanComeFromItsStatus() throws {
        #expect(try AntigravityUsageProvider.status(from: Data(status.utf8)) == .init(email: "someone@gmail.com", plan: "Google AI Pro"))
        let older = #"{"userStatus":{"email":"","planStatus":{"planInfo":{"planName":"Free"}}}}"#
        #expect(try AntigravityUsageProvider.status(from: Data(older.utf8)) == .init(email: nil, plan: "Free"))
    }

    @Test func limitsAreNamedByGroupAndTheFirstFillsTheUsualLines() throws {
        let groups = try AntigravityUsageProvider.groups(fromQuotaSummary: Data(summary.utf8))
        let snapshot = ProviderSnapshot(provider: .antigravity, updatedAt: .now, fiveHour: groups[0].fiveHour, weekly: groups[0].weekly,
                                        modelWeeklies: [], planName: nil, sourceDescription: "", note: nil,
                                        isStale: false, requiresLogin: false, limitGroups: groups)
        let metrics = DisplayMetric.all(snapshot)
        #expect(metrics.map(\.id) == ["5h", "weekly", "group:claude-gpt:weekly"])
        #expect(metrics.map(\.choiceTitle) == ["Gemini 5 hours", "Gemini weekly", "Claude/GPT weekly"])
        // A new account's line ("weekly") shows the first group's weekly limit.
        #expect(DisplayMetric.menuBar(snapshot, preferred: "weekly").window?.utilization == 0.6)
    }

    @Test func readingNeedsAntigravityRunningAndSignedInToTheSameAccount() async {
        let closed = AntigravityUsageProvider(locate: { nil })
        let waiting = await closed.load()
        #expect(waiting.isStale && !waiting.requiresLogin && waiting.note?.contains("isn't running") == true)

        func running(as email: String) -> AntigravityUsageProvider {
            AntigravityUsageProvider(expectedIdentity: AccountIdentity(email: email), locate: { .init(port: 1, token: "t") },
                                     transport: { request in
                #expect(request.value(forHTTPHeaderField: "X-Codeium-Csrf-Token") == "t")
                let body = request.url!.lastPathComponent == "GetUserStatus" ? status : summary
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
        }
        let live = await running(as: "Someone@gmail.com").load()
        #expect(!live.isStale && live.planName == "Google AI Pro" && live.weekly?.utilization == 0.6)
        #expect(live.limitGroups?.count == 2)
        let other = await running(as: "other@gmail.com").load()
        #expect(other.isStale && other.note?.contains("someone@gmail.com") == true)
    }
}

@MainActor
struct AntigravityAccountTests {
    @Test func onlyOneAntigravityAccountIsKept() throws {
        let suite = "AntigravityAccountTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("antigravity-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: files.root); defaults.removePersistentDomain(forName: suite) }
        let existing = UsageAccount(id: UUID(), provider: .antigravity, name: "someone@gmail.com",
                                    identity: AccountIdentity(email: "someone@gmail.com"), credentialID: UUID())
        var registry = AccountRegistry(accounts: [existing]); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        let store = UsageStore(settings: AppSettings(defaults: defaults), files: files, autoRefresh: false, edition: .pro)
        defer { store.shutdown() }
        // Refused before anything is read from Antigravity.
        store.startLogin(.antigravity)
        #expect(!store.isLoggingIn && store.errorMessage == UsageStore.antigravityLimitMessage)
    }
}
