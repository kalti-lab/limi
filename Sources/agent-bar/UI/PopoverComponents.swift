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
                Text(unavailableMessage ?? "Usage data is unavailable.")
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
        default: return "cpu"
        }
    }
}
