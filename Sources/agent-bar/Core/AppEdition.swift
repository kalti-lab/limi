import Foundation

/// Which build this is. Free and Pro ship through different channels, so the
/// edition is fixed when the app is built (`build-app.sh --edition free`
/// defines AGENTBAR_FREE), never unlocked from inside the app.
enum AppEdition: Sendable {
    case free
    case pro

    static let current: AppEdition = {
        #if AGENTBAR_FREE
        return .free
        #else
        return .pro
        #endif
    }()

    /// How many accounts this edition registers; nil means no limit.
    var accountLimit: Int? { self == .free ? 1 : nil }
    /// Pro edits menu bar groups; Free shows the default layout read-only.
    var customizesMenuBar: Bool { self == .pro }

    var title: String {
        switch self {
        case .free: return String(localized: "Free")
        case .pro: return "Pro"
        }
    }
}
