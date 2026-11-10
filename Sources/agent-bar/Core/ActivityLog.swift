import Foundation

// Appends one JSON object per line to logs/<file> in the data directory, such as the Claude Code switch log
// (claude-code-switch.log). Every line of one attempt shares an attempt ID. What a CLI printed is kept after
// redaction so a failed attempt can be diagnosed later; tokens and Authorization headers are never written.
// Taken from the original AgentBar's limit-reset log, without the parts only limit resets use.
struct ActivityLog: Sendable {
    private static let maximumSize = 1_000_000
    private static let maximumText = 20_000
    private static let lock = NSLock()
    private static let secretKeys = ["token", "authorization", "cookie", "secret", "password", "credential",
                                     "bearer", "apikey", "api_key", "api-key"]
    private static let secretPatterns = [
        #"eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}"#,
        #"sk-ant-[A-Za-z0-9_-]{8,}"#,
        #"(?i)bearer\s+[A-Za-z0-9._~+/=-]{8,}"#,
    ]

    let url: URL
    let provider: ProviderKind
    let accountID: UUID
    let accountName: String
    var attempt: UUID?

    init(root: URL, account: UsageAccount, attempt: UUID? = nil, fileName: String) {
        url = Self.url(root: root, fileName: fileName)
        provider = account.provider
        accountID = account.id
        accountName = account.title
        self.attempt = attempt
    }

    static func url(root: URL, fileName: String) -> URL { root.appendingPathComponent("logs/\(fileName)") }

    func record(_ event: String, _ details: [String: Any] = [:]) {
        var entry = details.mapValues(Self.sanitized)
        entry["time"] = Self.timestamp(.now)
        entry["event"] = event
        entry["provider"] = provider.rawValue
        entry["account"] = Self.redacted(accountName)
        entry["accountID"] = accountID.uuidString
        if let attempt { entry["attempt"] = attempt.uuidString }
        Self.append(entry, to: url)
    }

    static func sanitized(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return NSNull() }
            return sanitized(wrapped)
        }
        switch value {
        case let dictionary as [String: Any]:
            var result: [String: Any] = [:]
            for (key, item) in dictionary {
                let lowered = key.lowercased()
                result[key] = secretKeys.contains { lowered.contains($0) } ? "[redacted]" : sanitized(item)
            }
            return result
        case let array as [Any]: return array.map(sanitized)
        case let string as String: return redacted(string)
        case let date as Date: return timestamp(date)
        case let url as URL: return redacted(url.absoluteString)
        case let uuid as UUID: return uuid.uuidString
        case is NSNull: return value
        case let number as NSNumber: return number
        default: return redacted(String(describing: value))
        }
    }

    static func redacted(_ string: String) -> String {
        var result = string
        for pattern in secretPatterns {
            result = result.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
        }
        guard result.count > maximumText else { return result }
        return String(result.prefix(maximumText)) + "…[\(result.count - maximumText) more characters]"
    }

    private static func timestamp(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current).format(date)
    }

    private static func append(_ entry: [String: Any], to url: URL) {
        guard JSONSerialization.isValidJSONObject(entry),
              var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return }
        line.append(0x0a)
        lock.lock(); defer { lock.unlock() }
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if let size = try? manager.attributesOfItem(atPath: url.path)[.size] as? Int, size > maximumSize {
                let previous = directory.appendingPathComponent(url.lastPathComponent + ".1")
                try? manager.removeItem(at: previous)
                try manager.moveItem(at: url, to: previous)
            }
            if !manager.fileExists(atPath: url.path) {
                guard manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { return }
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {}
    }
}
