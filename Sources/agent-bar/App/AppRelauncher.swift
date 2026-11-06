import AppKit

/// Quits AgentBar and opens it again, so a new language reaches every piece of
/// text at once instead of leaving what is already on screen in the old one.
@MainActor
enum AppRelauncher {
    static let reopenSettingsKey = "reopenSettingsAfterRelaunch"

    /// Only a real app bundle can be opened again; `swift run` and tests cannot.
    static var canRelaunch: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static func relaunch(reopeningSettings: Bool) {
        guard canRelaunch else { return }
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Waits for this AgentBar to quit, then opens it again in the background.
        waiter.arguments = ["-c", "while kill -0 \"$0\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open -g \"$1\"",
                            String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundleURL.path]
        do { try waiter.run() } catch { return }
        if reopeningSettings { UserDefaults.standard.set(true, forKey: reopenSettingsKey) }
        NSApplication.shared.terminate(nil)
    }

    /// True once after a relaunch that asked to show Settings again.
    static func takeReopenSettingsRequest() -> Bool {
        guard UserDefaults.standard.bool(forKey: reopenSettingsKey) else { return false }
        UserDefaults.standard.removeObject(forKey: reopenSettingsKey)
        return true
    }
}
