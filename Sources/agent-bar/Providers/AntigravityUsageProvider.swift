import Foundation

/// Reads Antigravity limits from the Antigravity app or `agy` running on this
/// Mac, through its local language server, the way Antigravity shows them
/// itself. Limi never holds or sends an Antigravity sign-in: Google's terms
/// forbid third-party software using it, so only the account signed in there
/// can be read, and only while Antigravity runs.
///
/// Experimental: the local interface is not public and may change with any
/// Antigravity update. Its shape follows open-source quota monitors.
struct AntigravityUsageProvider: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    struct Endpoint: Equatable, Sendable {
        let port: Int
        let token: String
    }

    struct Status: Equatable, Sendable {
        let email: String?
        let plan: String?
    }

    var expectedIdentity: AccountIdentity?
    var locate: @Sendable () -> Endpoint? = { AntigravityUsageProvider.discover() }
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    // MARK: Finding the running Antigravity

    /// The local server's port and session token come from the same Antigravity
    /// process command line (`--hub-port=…`, `--csrf_token=…`): one whose
    /// program lives under Antigravity or is an `agy` binary.
    static func endpoint(fromProcessList output: String) -> Endpoint? {
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let program = line.components(separatedBy: " --").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let name = (program as NSString).lastPathComponent.lowercased()
            guard program.localizedCaseInsensitiveContains("antigravity") || name.hasPrefix("agy") else { continue }
            guard let port = flag("--hub-port=", in: line).flatMap(Int.init), (1...65_535).contains(port),
                  let token = flag("--csrf_token=", in: line) else { continue }
            return Endpoint(port: port, token: token)
        }
        return nil
    }

    private static func flag(_ name: String, in line: String) -> String? {
        guard let range = line.range(of: name) else { return nil }
        let value = line[range.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return value.isEmpty ? nil : String(value)
    }

    /// Lists this user's processes (`ps`), reading command lines only.
    static func discover() -> Endpoint? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axww", "-o", "command="]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return endpoint(fromProcessList: String(decoding: data, as: UTF8.self))
    }

    // MARK: Asking it

    private func call(_ method: String, at endpoint: Endpoint) async throws -> Data {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(endpoint.port)/exa.language_server_pb.LanguageServerService/\(method)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(endpoint.token, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AccountError.message(Self.changedMessage)
        }
        return data
    }

    // MARK: Reading its answers

    /// Each group's buckets carry a window ("5h" or "weekly"), the fraction
    /// left and when it resets. A missing fraction means nothing is used yet.
    static func groups(fromQuotaSummary data: Data) throws -> [LimitGroupSummary] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = root["response"] as? [String: Any] else { throw AccountError.message(changedMessage) }
        let groups = response["groups"] as? [[String: Any]] ?? []
        return groups.compactMap { group in
            let label = (group["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Models"
            var fiveHour: WindowSummary?
            var weekly: WindowSummary?
            for bucket in group["buckets"] as? [[String: Any]] ?? [] where bucket["disabled"] as? Bool != true {
                let left = min(max((bucket["remainingFraction"] as? NSNumber)?.doubleValue ?? 1, 0), 1)
                let window = WindowSummary(tokens: Int(((1 - left) * 100).rounded()), limitTokens: 100,
                                           resetAt: (bucket["resetTime"] as? String).flatMap(date), displayStyle: .percentage)
                switch (bucket["window"] as? String)?.lowercased() {
                case "5h", "five_hour", "fivehour": fiveHour = window
                case "weekly", "week", "7d", "seven_day": weekly = window
                default: continue
                }
            }
            return fiveHour == nil && weekly == nil ? nil : LimitGroupSummary(label: label, fiveHour: fiveHour, weekly: weekly)
        }
    }

    static func status(from data: Data) throws -> Status {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = root["userStatus"] as? [String: Any] else { throw AccountError.message(changedMessage) }
        let plan = ((user["userTier"] as? [String: Any])?["name"] as? String)
            ?? (((user["planStatus"] as? [String: Any])?["planInfo"] as? [String: Any])?["planName"] as? String)
        return Status(email: (user["email"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                      plan: plan.flatMap { $0.isEmpty ? nil : $0 })
    }

    private static func date(_ text: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    // MARK: For Limi

    /// The account signed in to the running Antigravity, for connecting it.
    func signedInAccount() async throws -> AccountIdentity {
        guard let endpoint = locate() else {
            throw AccountError.message(String(localized: "Open Antigravity or agy on this Mac and sign in, then try again."))
        }
        guard let email = try Self.status(from: try await call("GetUserStatus", at: endpoint)).email else {
            throw AccountError.message(String(localized: "Antigravity didn't report a signed-in account. Sign in to Antigravity, then try again."))
        }
        // The email is all Antigravity reports to tell accounts apart.
        return AccountIdentity(email: email, stableID: "antigravity:" + email.lowercased())
    }

    func load() async -> ProviderSnapshot {
        guard let endpoint = locate() else {
            return Self.waiting(String(localized: "Antigravity isn't running on this Mac. Open Antigravity or agy to refresh."))
        }
        do {
            let groups = try Self.groups(fromQuotaSummary: try await call("RetrieveUserQuotaSummary", at: endpoint))
            let status = try? await Self.status(from: call("GetUserStatus", at: endpoint))
            if let expected = expectedIdentity?.email, let email = status?.email,
               expected.caseInsensitiveCompare(email) != .orderedSame {
                return Self.waiting(String(localized: "Antigravity on this Mac is signed in to \(email), not this account."))
            }
            guard let first = groups.first else {
                return Self.waiting(String(localized: "Antigravity reported no limits for this account."))
            }
            return ProviderSnapshot(provider: .antigravity, updatedAt: .now,
                                    fiveHour: first.fiveHour ?? Self.empty, weekly: first.weekly ?? Self.empty,
                                    modelWeeklies: [], planName: status?.plan,
                                    sourceDescription: ProviderKind.antigravity.sourceDescription,
                                    note: nil, isStale: false, requiresLogin: false, limitGroups: groups)
        } catch {
            return Self.waiting(Self.changedMessage)
        }
    }

    private static let empty = WindowSummary(tokens: 0, limitTokens: 0, resetAt: nil, displayStyle: .percentage)

    private static var changedMessage: String {
        String(localized: "Couldn't read Antigravity usage. Antigravity may have changed in an update.")
    }

    /// Nothing new to show; the store keeps the last values with this note.
    private static func waiting(_ note: String) -> ProviderSnapshot {
        ProviderSnapshot.placeholder(for: .antigravity).failed(note)
    }
}
