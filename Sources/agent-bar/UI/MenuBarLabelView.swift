import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        if let nsImage = renderedImage() {
            Image(nsImage: nsImage)
        } else {
            Text(fallbackText)
        }
    }

    private var fallbackText: String {
        let percent = TokenFormatters.percentageString(for: snapshot.fiveHour.utilization)
        return "\(snapshot.provider.shortName) \(percent)"
    }

    @MainActor
    private func renderedImage() -> NSImage? {
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2.0
        let renderer = ImageRenderer(content: RenderedLabel(snapshot: snapshot))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}

private struct RenderedLabel: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        (
            Text("\(Image(systemName: gaugeSymbol)) ")
                .fontWeight(.regular)
            + Text(snapshot.provider.shortName)
                .fontWeight(.bold)
            + Text(" \(percentText)")
                .fontWeight(.medium)
        )
        .font(.system(size: 11))
        .monospacedDigit()
        .foregroundStyle(.black)
        .padding(.vertical, 2)
        .padding(.horizontal, 1)
    }

    private var percentText: String {
        TokenFormatters.percentageString(for: snapshot.fiveHour.utilization)
    }

    private var gaugeSymbol: String {
        guard let utilization = snapshot.fiveHour.utilization else {
            return "gauge.with.dots.needle.0percent"
        }
        let pct = utilization * 100
        switch pct {
        case ..<20: return "gauge.with.dots.needle.0percent"
        case ..<40: return "gauge.with.dots.needle.33percent"
        case ..<60: return "gauge.with.dots.needle.50percent"
        case ..<80: return "gauge.with.dots.needle.67percent"
        default: return "gauge.with.dots.needle.100percent"
        }
    }
}
