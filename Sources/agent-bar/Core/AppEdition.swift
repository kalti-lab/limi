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

    /// Where the free edition sends people to buy Pro, set at build time
    /// (AGENTBAR_PURCHASE_URL becomes the Info.plist key AgentBarPurchaseURL).
    /// Nil until the site exists; only an https address is used.
    static let purchaseURL: URL? = purchaseURL(from: Bundle.main.object(forInfoDictionaryKey: "AgentBarPurchaseURL") as? String)

    static func purchaseURL(from value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
              let url = URL(string: value), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { return nil }
        return url
    }

    var title: String {
        switch self {
        case .free: return String(localized: "Free")
        case .pro: return "Pro"
        }
    }
}
