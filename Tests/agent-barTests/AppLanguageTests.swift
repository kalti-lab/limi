import Foundation
import Testing
@testable import agent_bar

@MainActor
struct AppLanguageTests {
    private func freshDefaults() -> (UserDefaults, String) {
        let suite = "AppLanguageTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func englishUnlessKoreanIsChosen() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        // Even on a Mac set to Korean, a new AgentBar starts in English.
        #expect(AppLanguage.stored(in: defaults) == .english)
        #expect(AppSettings(defaults: defaults).language == .english)
        defaults.set("fr", forKey: AppLanguage.defaultsKey)
        #expect(AppLanguage.stored(in: defaults) == .english)
    }

    @Test func theChoiceIsKeptAndAppliedToTheAppsOwnLanguages() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        AppSettings(defaults: defaults).language = .korean
        #expect(AppSettings(defaults: defaults).language == .korean)
        // Applied to a scratch domain here, never the test runner's own.
        AppLanguage.korean.apply(to: defaults)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ko"])
    }

    @Test func eachLanguageNamesItself() {
        #expect(AppLanguage.allCases.map(\.nativeName) == ["English", "한국어"])
    }
}
