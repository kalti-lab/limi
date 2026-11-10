import Foundation

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let settings: AppSettings
    let store: UsageStore
    let availableProviders: [ProviderKind]

    private init() {
        let environment = ProcessInfo.processInfo.environment
        let defaults = environment["AGENTBAR_DEFAULTS_SUITE"].flatMap(UserDefaults.init(suiteName:)) ?? .standard
        let settings = AppSettings(defaults: defaults)
        let files = environment["AGENTBAR_DATA_DIR"].map { AccountFiles(root: URL(fileURLWithPath: $0)) } ?? AccountFiles()
        let availableProviders = ProviderAvailability.availableProviders()
        self.settings = settings
        self.availableProviders = availableProviders
        // The one place that can change Claude Code's own login. Tests build a store without it, or with a stand-in.
        let isAppBundle = Bundle.main.bundleURL.pathExtension == "app"
        self.store = UsageStore(settings: settings, files: files,
                                claudeCode: Self.claudeCodeAllowed(environment, isAppBundle: isAppBundle) ? .system(files: files) : nil)
    }

    // "Use in Claude Code" changes the login Claude Code itself uses, whatever data folder the app was given. Only the app
    // gets a switcher: `swift run`, or a run with its own data folder or defaults, is a development or test run. It must
    // not change that login, nor finish a switch the installed app has under way in the same folder.
    nonisolated static func claudeCodeAllowed(_ environment: [String: String], isAppBundle: Bool) -> Bool {
        isAppBundle && environment["AGENTBAR_DATA_DIR"] == nil && environment["AGENTBAR_DEFAULTS_SUITE"] == nil
    }
}
