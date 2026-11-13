import Foundation

enum TokenFormatters {
    // Times read in the language the app is shown in: English by default,
    // Korean when the Mac prefers it, so "2 min. ago" never sits in Korean text.
    private static let displayLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en_US")

    private static func makeRelativeFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = displayLocale
        return formatter
    }

    private static func makeCountdownFormatter() -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = displayLocale
        formatter.calendar = calendar
        return formatter
    }

    static func percentageString(for utilization: Double?) -> String {
        guard let utilization else { return "--" }
        return "\(Int((utilization * 100).rounded()))%"
    }

    static func resetLabelString(from now: Date = .now, resetAt: Date?) -> String {
        guard let resetAt else { return String(localized: "No reset time") }

        let interval = resetAt.timeIntervalSince(now)
        if interval <= 0 {
            return String(localized: "Resets soon")
        }

        if interval < 60 {
            return String(localized: "Resets in less than 1m")
        }

        if let formatted = makeCountdownFormatter().string(from: interval), formatted.isEmpty == false {
            return String(localized: "Resets in \(formatted)")
        }

        // The relative phrase already says "in 3 days", so it follows "Resets" directly.
        return String(localized: "Resets \(makeRelativeFormatter().localizedString(for: resetAt, relativeTo: now))")
    }

    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func relativeUpdateString(from now: Date = .now, updatedAt: Date) -> String {
        let interval = abs(now.timeIntervalSince(updatedAt))
        if interval < 5 {
            return String(localized: "just now")
        }
        return makeRelativeFormatter().localizedString(for: updatedAt, relativeTo: now)
    }
}
