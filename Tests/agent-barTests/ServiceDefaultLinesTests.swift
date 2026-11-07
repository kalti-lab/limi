import Foundation
import Testing
@testable import agent_bar

private func window(_ used: Int) -> WindowSummary {
    WindowSummary(tokens: used, limitTokens: 100, resetAt: nil, displayStyle: .percentage)
}

private func antigravity(_ groups: [LimitGroupSummary]) -> ProviderSnapshot {
    ProviderSnapshot(provider: .antigravity, updatedAt: .now, fiveHour: groups.first?.fiveHour, weekly: groups.first?.weekly,
                     modelWeeklies: [], planName: nil, sourceDescription: "", note: nil,
                     isStale: false, requiresLogin: false, limitGroups: groups)
}

private func account(_ provider: ProviderKind) -> UsageAccount {
    UsageAccount(id: UUID(), provider: provider, name: provider.displayName, credentialID: UUID())
}

struct ServiceDefaultLinesTests {
    @Test func antigravityStartsWithEachModelGroupsWeeklyLine() {
        let free = antigravity([LimitGroupSummary(label: "Gemini Models", fiveHour: nil, weekly: window(0)),
                                LimitGroupSummary(label: "Claude and GPT models", fiveHour: nil, weekly: window(0))])
        #expect(DisplayMetric.firstLines(free) == ["weekly", "group:claude-and-gpt-models:weekly"])
        // Paid accounts also have 5-hour limits; the weekly one still comes first.
        let paid = antigravity([LimitGroupSummary(label: "Gemini", fiveHour: window(10), weekly: window(20)),
                                LimitGroupSummary(label: "Claude/GPT", fiveHour: window(30), weekly: nil)])
        #expect(DisplayMetric.firstLines(paid) == ["weekly", "group:claude-gpt:5h"])
    }

    @Test func otherServicesStartWithTheirWeeklyLine() {
        #expect(DisplayMetric.firstLines(ProviderSnapshot.placeholder(for: .claude)) == ["weekly"])
        #expect(DisplayMetric.firstLines(nil) == ["weekly"])
        // One model group needs no more than the usual line.
        #expect(DisplayMetric.firstLines(antigravity([LimitGroupSummary(label: "Gemini", fiveHour: nil, weekly: window(0))])) == ["weekly"])
    }

    @Test func onlyClaudeKeepsAFableChoice() {
        let claude = account(.claude), codex = account(.codex), agy = account(.antigravity)
        var config = DisplayConfiguration()
        config.sync([claude, codex, agy])
        #expect(config.display(claude).bars.contains("model:fable"))
        #expect(config.display(codex).bars == ["5h", "weekly"])
        #expect(config.display(agy).bars == ["5h", "weekly"])
        // Accounts saved by earlier versions lose it too, with or without groups.
        config.layouts = config.effectiveLayouts
        config.update(codex.id) { $0.bars.insert("model:fable") }
        config.update(agy.id) { $0.bars.insert("model:fable") }
        config.sync([claude, codex, agy])
        #expect(!config.display(codex).bars.contains("model:fable") && !config.display(agy).bars.contains("model:fable"))
        #expect(config.display(claude).bars.contains("model:fable"))
    }

    @Test func firstLinesReplaceTheSingleWeeklyLineAsFarAsTheGroupHasRoom() {
        let claude = account(.claude), agy = account(.antigravity)
        var config = DisplayConfiguration()
        config.sync([claude])
        config.layouts = config.effectiveLayouts
        config.sync([claude, agy])
        let lines = ["weekly", "group:claude-and-gpt-models:weekly"]
        config.setFirstLines(agy.id, lines)
        let own = config.layouts?.first { $0.rows.contains { $0.accountID == agy.id } }
        #expect(own?.rows.map(\.metricID) == lines)
        #expect(config.display(agy).primary == "weekly" && config.display(agy).bars == Set(lines))

        // Sharing a group with two other lines leaves room for one.
        var shared = config
        shared.editLayouts { layouts in
            let index = layouts.firstIndex { $0.rows.contains { $0.accountID == agy.id } }!
            layouts[index].rows = [MenuBarLine(accountID: claude.id, metricID: "5h"), MenuBarLine(accountID: claude.id, metricID: "weekly"),
                                   MenuBarLine(accountID: agy.id, metricID: "weekly")]
        }
        shared.setFirstLines(agy.id, lines)
        let group = shared.layouts?.first { $0.rows.contains { $0.accountID == agy.id } }
        #expect(group?.rows.filter { $0.accountID == agy.id }.map(\.metricID) == ["weekly"] && group?.rows.count == 3)
    }
}

@MainActor
struct NewAccountLinesTests {
    @Test func aNewAntigravityAccountGetsALinePerModelGroup() throws {
        let suite = "NewAccountLinesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("first-lines-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: files.root); defaults.removePersistentDomain(forName: suite) }
        let store = UsageStore(settings: AppSettings(defaults: defaults), files: files, autoRefresh: false, edition: .pro,
                               loadAccount: { account, _ in ProviderSnapshot.placeholder(for: account.provider) })
        defer { store.shutdown() }
        var signedIn = account(.antigravity)
        signedIn.identity = AccountIdentity(email: "someone@gmail.com", stableID: "antigravity:someone@gmail.com")
        let lines = ["weekly", "group:claude-and-gpt-models:weekly"]
        store.presentCompletedLogin(signedIn, replacing: nil, firstLines: lines)
        store.confirmLogin()
        #expect(store.accounts.contains { $0.id == signedIn.id })
        let group = store.displayConfiguration.layouts?.first { $0.rows.contains { $0.accountID == signedIn.id } }
        #expect(group?.rows.map(\.metricID) == lines)
    }
}
