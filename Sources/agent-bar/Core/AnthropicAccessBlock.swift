import Foundation

/// Anthropic's answer when it stops apps other than Claude Code from using a
/// Claude sign-in, as it did for third-party clients in 2026. Told apart from
/// an expired or revoked sign-in, so people are not sent to reconnect, which
/// cannot help. Matching is by the wording of that refusal: a plain
/// "token expired" still means sign in again.
enum AnthropicAccessBlock {
    private static let phrases = ["only authorized for use with claude code", "third-party", "third party"]

    static func matches(status: Int, body: Data) -> Bool {
        guard [400, 401, 403].contains(status) else { return false }
        let text = String(decoding: body.prefix(8192), as: UTF8.self).lowercased()
        return phrases.contains { text.contains($0) }
    }

    static var message: String {
        String(localized: "Anthropic is blocking apps other than Claude Code from reading Claude usage. Reconnecting will not help; check for a \(AppInfo.name) update.")
    }
}
