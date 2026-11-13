import SwiftUI

extension DisplayMetric {
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
