import SwiftUI

// What a row shows about its usage-reset coupons: the coupons it can use, and the line while one is being used.
struct CouponPanel: Equatable {
    enum Line: Equatable {
        // "Reset" was pressed: the question, with Cancel and OK.
        case confirmation
        case progress
        // How it ended, and how many coupons are left after a reset when the service counts them.
        case result(CouponOutcome, left: Int?)
    }

    var coupons: UsageResetCoupons?
    var line: Line?

    static let none = CouponPanel(coupons: nil, line: nil)

    var scope: UsageResetCoupons.Scope { coupons?.scope ?? .fiveHourAndWeekly }
    // Whether the row has a coupon line at all. With no coupon and nothing going on it has none, as before.
    var shows: Bool { line != nil || coupons?.usable != nil }
}

// Every coupon word in one place, so the line, its help and VoiceOver say the same. `bundle` is for tests that measure the
// Korean words; the app uses the main bundle.
enum CouponWords {
    static func reset(_ bundle: Bundle = .main) -> String { String(localized: "Reset", bundle: bundle) }
    static func ok(_ bundle: Bundle = .main) -> String { String(localized: "OK", bundle: bundle) }
    static func cancel(_ bundle: Bundle = .main) -> String { String(localized: "Cancel", bundle: bundle) }
    static func resetting(_ bundle: Bundle = .main) -> String { String(localized: "Resetting…", bundle: bundle) }
    static func help(_ bundle: Bundle = .main) -> String {
        String(localized: "Click to reset this account's limits with a coupon.", bundle: bundle)
    }

    // Separate sentences for one and many, since Korean does not add an "s".
    static func count(_ count: Int, _ bundle: Bundle = .main) -> String {
        count == 1 ? String(localized: "1 reset coupon", bundle: bundle) : String(localized: "\(count) reset coupons", bundle: bundle)
    }

    // "3 reset coupons · 1 expires Dec 1", or "1 reset coupon · 5-hour only".
    static func summary(_ coupons: UsageResetCoupons, _ bundle: Bundle = .main) -> String {
        var parts = [count(coupons.count, bundle)]
        if coupons.scope == .fiveHour { parts.append(String(localized: "5-hour only", bundle: bundle)) }
        if coupons.scope == .weekly { parts.append(String(localized: "weekly only", bundle: bundle)) }
        if let expiry = expiry(coupons, bundle) { parts.append(expiry) }
        return parts.joined(separator: " · ")
    }

    // When the first coupon expires, and how many go then.
    static func expiry(_ coupons: UsageResetCoupons, _ bundle: Bundle = .main) -> String? {
        let sorted = coupons.expiries.sorted()
        guard let first = sorted.first else { return nil }
        let going = sorted.filter { Calendar.current.isDate($0, inSameDayAs: first) }.count
        let date = day(first, bundle)
        if going >= coupons.count { return String(localized: "expires \(date)", bundle: bundle) }
        return going == 1 ? String(localized: "1 expires \(date)", bundle: bundle)
                          : String(localized: "\(going) expire \(date)", bundle: bundle)
    }

    // The question before a coupon is used.
    static func question(_ scope: UsageResetCoupons.Scope, _ bundle: Bundle = .main) -> String {
        switch scope {
        case .fiveHourAndWeekly: String(localized: "Use 1 coupon to reset 5h and weekly now?", bundle: bundle)
        case .fiveHour: String(localized: "Use 1 coupon to reset only the 5h limit?", bundle: bundle)
        case .weekly: String(localized: "Use 1 coupon to reset only the weekly limit?", bundle: bundle)
        }
    }

    static func message(_ outcome: CouponOutcome, left: Int?, scope: UsageResetCoupons.Scope, _ bundle: Bundle = .main) -> String {
        switch outcome {
        case .reset:
            let done = switch scope {
            case .fiveHour: String(localized: "The 5-hour limit is reset.", bundle: bundle)
            case .weekly: String(localized: "The weekly limit is reset.", bundle: bundle)
            case .fiveHourAndWeekly: String(localized: "The 5-hour and weekly limits are reset.", bundle: bundle)
            }
            guard let left, left > 0 else { return done }
            return done + " " + (left == 1 ? String(localized: "1 coupon left.", bundle: bundle)
                                           : String(localized: "\(left) coupons left.", bundle: bundle))
        case .nothingToReset: return String(localized: "Nothing to reset yet. The coupon wasn't used.", bundle: bundle)
        case .noCoupon: return String(localized: "No coupons left.", bundle: bundle)
        case .signInAgain: return String(localized: "Couldn't reset. Sign in again in Settings › Accounts.", bundle: bundle)
        case .tryLater: return String(localized: "Couldn't reset. Try again in a moment.", bundle: bundle)
        }
    }

    // "Dec 1" or "12월 1일", in the language the words are in.
    static func day(_ date: Date, _ bundle: Bundle = .main) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: bundle.preferredLocalizations.first ?? "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}

// The coupon line under a row's bars. One line, always as tall as a line with a button, so the row does not move when the
// offer turns into the question, the wait or how it ended. The buttons sit at its right end.
struct CouponLineView: View {
    let panel: CouponPanel
    var use: () -> Void = {}
    // OK and Cancel on the question.
    var confirm: () -> Void = {}
    var cancel: () -> Void = {}
    // Where the words come from; tests measure the Korean ones.
    var bundle: Bundle = .main

    var body: some View {
        ZStack(alignment: .leading) {
            GroupAccountRow.buttonHeightTemplate
            HStack(spacing: 5) {
                content
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
    }

    // A line with a bordered button: the caption's line and the button's padding.
    static let height: CGFloat = 20

    @ViewBuilder private var content: some View {
        switch panel.line {
        case nil:
            if let coupons = panel.coupons?.usable {
                icon("ticket", .secondary)
                words(CouponWords.summary(coupons, bundle), .secondary)
                Spacer(minLength: 6)
                Button(action: use) { Text(verbatim: CouponWords.reset(bundle)).font(GroupAccountRow.buttonFont) }
                    .buttonStyle(PanelBorderedButtonStyle())
                    .fixedSize()
                    .help(CouponWords.help(bundle))
            }
        case .confirmation:
            icon("ticket", .secondary)
            words(CouponWords.question(panel.scope, bundle), .primary)
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Button(action: cancel) { Text(verbatim: CouponWords.cancel(bundle)).font(GroupAccountRow.buttonFont) }
                Button(action: confirm) { Text(verbatim: CouponWords.ok(bundle)).font(GroupAccountRow.buttonFont) }
            }
            .buttonStyle(PanelBorderedButtonStyle())
            .fixedSize()
        case .progress:
            ProgressView().controlSize(.mini).frame(width: 12, height: 12)
            words(CouponWords.resetting(bundle), .secondary)
            Spacer(minLength: 0)
        case .result(let outcome, let left):
            icon(Self.symbol(outcome), Self.tint(outcome))
            words(CouponWords.message(outcome, left: left, scope: panel.scope, bundle), Self.attention(outcome) ? .orange : .secondary)
            Spacer(minLength: 0)
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name).foregroundStyle(color).frame(width: 12).accessibilityHidden(true)
    }

    private func words(_ text: String, _ color: Color) -> some View {
        Text(verbatim: text).foregroundStyle(color).lineLimit(1).truncationMode(.tail)
    }

    static func symbol(_ outcome: CouponOutcome) -> String {
        switch outcome {
        case .reset: "checkmark.circle.fill"
        case .nothingToReset: "info.circle"
        case .noCoupon, .signInAgain, .tryLater: "exclamationmark.triangle.fill"
        }
    }

    static func tint(_ outcome: CouponOutcome) -> Color {
        switch outcome {
        case .reset: .green
        case .nothingToReset: .secondary
        case .noCoupon, .signInAgain, .tryLater: .orange
        }
    }

    static func attention(_ outcome: CouponOutcome) -> Bool {
        switch outcome {
        case .reset, .nothingToReset: false
        case .noCoupon, .signInAgain, .tryLater: true
        }
    }
}
