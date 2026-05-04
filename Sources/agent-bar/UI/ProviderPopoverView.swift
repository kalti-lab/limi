import AppKit
import SwiftUI

struct ProviderPopoverView: View {
    let snapshot: ProviderSnapshot

    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            WindowCard(
                title: "5-Hour Session",
                systemImage: "clock",
                window: snapshot.fiveHour
            )
            Divider()
            WindowCard(
                title: "Weekly Limit",
                systemImage: "calendar",
                window: snapshot.weekly
            )
            Divider()
            summarySection

            if let note = snapshot.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Text("\(snapshot.provider.displayName) Usage")
                .font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    store.refreshNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Usage Details")
                .font(.subheadline.weight(.semibold))

            LabeledContent("Plan", value: snapshot.planName ?? "n/a")
            LabeledContent("Today", value: TokenFormatters.compactTokenString(snapshot.todayTokens))
            LabeledContent("Month", value: TokenFormatters.compactTokenString(snapshot.monthTokens))
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            Text(snapshot.isStale
                 ? "Last good value \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))"
                 : "Updated \(TokenFormatters.relativeUpdateString(updatedAt: snapshot.updatedAt))")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

private struct WindowCard: View {
    let title: String
    let systemImage: String
    let window: WindowSummary

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
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(TokenFormatters.resetLabelString(resetAt: window.resetAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
