import AppKit
import SwiftUI

struct ProviderPopoverView: View {
    let snapshot: ProviderSnapshot

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                WindowCard(
                    title: "5-Hour Session",
                    window: snapshot.fiveHour,
                    color: settings.tintColor
                )
                Divider()
                WindowCard(
                    title: "Weekly Limit",
                    window: snapshot.weekly,
                    color: settings.accentColor
                )
                Divider()
                summarySection
                Divider()
                customizeSection
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 320, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Text("\(snapshot.provider.displayName) Usage")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                store.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Usage Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            SummaryRow(label: "Plan", value: snapshot.planName ?? "n/a")
            SummaryRow(label: "This Mac Today", value: TokenFormatters.compactTokenString(snapshot.todayTokens))
            SummaryRow(label: "This Mac Month", value: TokenFormatters.compactTokenString(snapshot.monthTokens))

            if let note = snapshot.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customize")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            ColorPaletteRow(label: "5-Hour", selectedIndex: $settings.tintColorIndex)
            ColorPaletteRow(label: "Weekly", selectedIndex: $settings.accentColorIndex)

            HStack {
                Text("Bar Width")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Slider(value: $settings.barWidth, in: 16...60)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.isStale ? "Last good value \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))" : "Updated \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }
}

private struct WindowCard: View {
    let title: String
    let window: WindowSummary
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(TokenFormatters.percentageString(for: window.utilization))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
            }

            ProgressView(value: min(window.utilization ?? 0, 1))
                .tint(color)

            HStack {
                switch window.displayStyle {
                case .percentage:
                    Text("Used \(window.tokens)%")
                case .tokens:
                    Text("Used \(TokenFormatters.compactTokenString(window.tokens))")
                    Spacer()
                    Text("Budget \(TokenFormatters.compactTokenString(window.limitTokens))")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Text(TokenFormatters.resetLabelString(resetAt: window.resetAt))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ColorPaletteRow: View {
    let label: String
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            ForEach(0..<AppSettings.palette.count, id: \.self) { index in
                Circle()
                    .fill(AppSettings.palette[index])
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: selectedIndex == index ? 2 : 0)
                    )
                    .onTapGesture { selectedIndex = index }
            }
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 11))
    }
}
