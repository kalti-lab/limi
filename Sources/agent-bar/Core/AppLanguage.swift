import Foundation

/// The language AgentBar shows. It is the app's own choice, English unless
/// chosen otherwise in Settings, not whatever language the Mac uses.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case korean = "ko"

    static let defaultsKey = "uiLanguage"
    var id: String { rawValue }

    /// Each language names itself, so it can be found from either one.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }

    static func stored(in defaults: UserDefaults) -> Self {
        defaults.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .english
    }

    /// The language this running AgentBar shows: the one it launched with.
    static var inUse: Self {
        Bundle.main.preferredLocalizations.first.flatMap(Self.init(rawValue:)) ?? .english
    }

    /// Makes the app use this language from its next lookup on: the app's own
    /// AppleLanguages comes before the Mac's. Text already shown keeps its
    /// language until AgentBar restarts.
    func apply(to appDefaults: UserDefaults = .standard) {
        appDefaults.set([rawValue], forKey: "AppleLanguages")
    }
}
