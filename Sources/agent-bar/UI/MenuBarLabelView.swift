import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: ProviderSnapshot
    let isDark: Bool

    @EnvironmentObject private var settings: AppSettings

    private var textColor: Color {
        isDark ? .white : .black
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(snapshot.provider.shortName)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(textColor)
                .frame(width: 18, height: 16)
            DualUsageBars(
                primary: snapshot.fiveHour.utilization,
                secondary: snapshot.weekly.utilization,
                primaryColor: settings.tintColor,
                secondaryColor: settings.accentColor
            )
            .frame(width: settings.barWidth, height: 8)

            Text(TokenFormatters.percentageString(for: snapshot.fiveHour.utilization))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(textColor.opacity(0.96))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Color.clear)
    }
}

struct DualUsageBars: View {
    let primary: Double?
    let secondary: Double?
    let primaryColor: Color
    let secondaryColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let topWidth = width * CGFloat(min(primary ?? 0, 1))
            let bottomWidth = width * CGFloat(min(secondary ?? 0, 1))
            let barCornerRadius = CGFloat(1.6)

            VStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(AppTheme.track)
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(primaryColor)
                        .frame(width: topWidth)
                }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(AppTheme.track)
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(secondaryColor)
                        .frame(width: bottomWidth)
                }
            }
        }
    }
}
