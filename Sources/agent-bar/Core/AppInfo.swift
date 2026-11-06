import Foundation

/// The app's name as people see it. It comes from the bundle, which
/// build-app.sh names from its `app_name` setting, so renaming the app is one
/// build setting rather than a code change. Internal names (the bundle ID
/// dev.chenjing.agent-bar, the ~/.agentbar data folder, the agent-bar module
/// and AGENTBAR_ variables) stay fixed, so a rename keeps settings and accounts.
enum AppInfo {
    static let defaultName = "Limi"

    static let name: String = {
        // `swift run` and tests have no app bundle to name them.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return defaultName }
        let info = Bundle.main.infoDictionary ?? [:]
        let named = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
        return named.flatMap { $0.isEmpty ? nil : $0 } ?? defaultName
    }()

    static var proName: String { "\(name) Pro" }
}
