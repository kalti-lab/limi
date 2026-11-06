import Foundation
import Testing

// The Korean strings ship in the app bundle; the tests run in English. These
// checks keep the file loadable and every translation's placeholders intact,
// since a missing or reordered %@ or %lld garbles or crashes the text.
struct LocalizationTests {
    private var korean: [String: String]? {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return NSDictionary(contentsOf: root.appendingPathComponent("assets/ko.lproj/Localizable.strings")) as? [String: String]
    }

    private func placeholders(_ text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:%|@|lld|d)")
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
    }

    @Test func koreanStringsLoadAndKeepEveryPlaceholderInOrder() throws {
        let strings = try #require(korean)
        #expect(strings.count > 200)
        for (key, value) in strings {
            #expect(!value.isEmpty, "\(key)")
            #expect(placeholders(key) == placeholders(value), "\(key) → \(value)")
        }
    }
}
