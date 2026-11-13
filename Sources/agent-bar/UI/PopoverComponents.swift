import SwiftUI

struct WindowCard: View {
    let title: String
    var systemImage: String = "chart.bar"
    let window: WindowSummary
    var unavailableMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(TokenFormatters.percentageString(for: window.utilization))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }

            ProgressView(value: min(window.utilization ?? 0, 1))

            if window.utilization == nil {
                Text(unavailableMessage ?? String(localized: "Usage data is unavailable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    switch window.displayStyle {
                    case .percentage:
                        Text("Used \(window.tokens)%")
                        Spacer()
                        Text("Remaining \(max(0, 100 - window.tokens))%")
                    case .tokens:
                        Text("Used \(TokenFormatters.compactTokenString(window.tokens))")
                        Spacer()
                        Text("Budget \(TokenFormatters.compactTokenString(window.limitTokens))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(TokenFormatters.resetLabelString(resetAt: window.resetAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

extension DisplayMetric {
    // 5-hour and weekly cards are told apart by symbol, not color.
    var systemImage: String {
        switch id {
        case "5h": return "clock"
        case "weekly": return "calendar"
        default:
            if id.hasPrefix("group:") { return id.hasSuffix(":5h") ? "clock" : "calendar" }
            return "cpu"
        }
    }

    /// The name over a limit in a group's account list, where three share a row: "5h", "Week", a model ("Fable"), or an
    /// Antigravity group's limit ("Gemini 5h").
    var cellTitle: String {
        if group != nil { return compactChoiceTitle }
        switch id {
        case "5h": return String(localized: "5h")
        case "weekly": return String(localized: "Week")
        default: return compactChoiceTitle
        }
    }
}

/// An account's plan in a small grey capsule, beside its name.
struct PlanTag: View {
    let plan: String
    var body: some View {
        Text(plan).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .accessibilityLabel("\(plan) plan")
    }
}

/// A colored dot and a short line: updated, waiting, or what needs attention.
struct AccountStatusLine: View {
    let status: AccountCardStatus
    var body: some View {
        let line = HStack(spacing: 5) {
            Circle().fill(dotColor).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(status.text).font(.caption).lineLimit(1)
                .foregroundStyle(status.tone == .attention ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        }
        if let detail = status.detail { line.help(detail) } else { line }
    }
    private var dotColor: Color {
        switch status.tone {
        case .ok: return .green
        case .attention: return .orange
        case .quiet: return Color.secondary.opacity(0.5)
        }
    }
}
