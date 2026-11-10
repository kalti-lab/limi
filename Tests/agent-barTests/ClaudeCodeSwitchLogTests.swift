import Foundation
import Testing
@testable import agent_bar

// The Claude Code switch log: one JSON object per line in its own file under logs/.
struct ClaudeCodeSwitchLogTests {
    @Test func theSwitchLogHasItsOwnFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-log-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UsageAccount(id: UUID(), provider: .claude, name: "work@example.test", identity: AccountIdentity(email: "work@example.test"))

        let switches = ActivityLog(root: root, account: account, attempt: UUID(), fileName: ActivityLog.claudeCodeSwitchFileName)
        switches.record("start")

        #expect(switches.url == root.appendingPathComponent("logs/claude-code-switch.log"))
        #expect(ActivityLog.claudeCodeSwitchURL(root: root) == switches.url)
        let switched = try #require(lines(of: switches.url).first)
        #expect(switched["event"] as? String == "start" && switched["account"] as? String == "work@example.test")
        #expect(switched["attempt"] as? String != nil && switched["provider"] as? String == "claude" && switched["time"] != nil)
        #expect(lines(of: switches.url).count == 1)
        // Private: only this macOS user can read it.
        #expect(permissions(switches.url) == 0o600 && permissions(switches.url.deletingLastPathComponent()) == 0o700)
    }

    @Test func tokensAndSecretLookingValuesAreNotWritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-log-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let log = ActivityLog(root: root, account: UsageAccount(id: UUID(), provider: .claude, name: "a"),
                                attempt: UUID(), fileName: ActivityLog.claudeCodeSwitchFileName)

        // Values are matched by what they look like; inside a nested object, keys that name a secret are blanked too.
        log.record("step", ["output": "failed with sk-ant-ort01-ABCDEFGHIJKLMNOP and Bearer abcdefgh12345678",
                            "nested": ["refreshToken": "FAKE-REFRESH-1", "accessToken": "FAKE-ACCESS-1", "note": "ok"]])

        let text = try String(contentsOf: log.url, encoding: .utf8)
        #expect(!text.contains("FAKE-REFRESH-1") && !text.contains("FAKE-ACCESS-1") && !text.contains("sk-ant-ort01") && !text.contains("abcdefgh12345678"))
        #expect(text.contains("[redacted]") && text.contains("failed with"))
    }

    @Test func theSwitchLogMovesToDotOneAroundOneMegabyte() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-log-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let log = ActivityLog(root: root, account: UsageAccount(id: UUID(), provider: .claude, name: "a"),
                                attempt: UUID(), fileName: ActivityLog.claudeCodeSwitchFileName)
        let filler = String(repeating: "x", count: 15_000)
        for index in 0..<80 { log.record("step", ["index": index, "filler": filler]) }

        let previous = log.url.deletingLastPathComponent().appendingPathComponent("claude-code-switch.log.1")
        #expect(FileManager.default.fileExists(atPath: previous.path))
        let size = try #require(FileManager.default.attributesOfItem(atPath: log.url.path)[.size] as? Int)
        #expect(size < 1_100_000)
        #expect(lines(of: log.url).count + lines(of: previous).count == 80)
    }

    private func lines(of url: URL) -> [[String: Any]] {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n").compactMap {
            try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]
        }
    }
}
