import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// Automatic updates (Sparkle). scripts/build-app.sh links Sparkle and writes the
/// feed (SUFeedURL, https://kalti.co.kr/limi/appcast.xml) and the public key every
/// update must be signed with (SUPublicEDKey) into Info.plist. Sparkle then looks
/// once a day without asking first. A plain `swift build` or `swift test` has no
/// Sparkle and none of this.
///
/// Limi lives in the menu bar and never takes focus from the app a person is
/// using, and an update must not either: with gentle reminders declared, Sparkle
/// (2.2 and later) shows an update it found by itself behind the other apps
/// instead of bringing Limi to the front.
enum Updates {
    @MainActor static func start() {
        #if canImport(Sparkle)
        UpdateDriver.shared.start()
        #endif
    }
}

#if canImport(Sparkle)
@MainActor
private final class UpdateDriver: NSObject, SPUStandardUserDriverDelegate {
    static let shared = UpdateDriver()
    private var controller: SPUStandardUpdaterController?

    func start() {
        // A bundle without a feed and key (made some other way) has nothing to check.
        guard controller == nil,
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
#endif
