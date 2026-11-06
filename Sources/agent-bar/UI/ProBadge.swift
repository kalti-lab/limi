import AppKit
import SwiftUI

/// Marks a feature of AgentBar Pro in the free edition, so the feature stays in
/// sight instead of disappearing. Opens the purchase page once the build has one.
struct ProBadge: View {
    var body: some View {
        if let url = AppEdition.purchaseURL {
            Button { NSWorkspace.shared.open(url) } label: { badge }
                .buttonStyle(.plain)
                .help("Open the AgentBar Pro page")
        } else {
            badge.help("Available in AgentBar Pro")
        }
    }

    // The blue-to-purple of the app icon's bars.
    private var badge: some View {
        Text(verbatim: "PRO")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(LinearGradient(colors: [Color(red: 0.35, green: 0.66, blue: 1.0), Color(red: 0.48, green: 0.30, blue: 0.91)],
                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
            .accessibilityLabel(Text(verbatim: "AgentBar Pro"))
    }
}

/// Opens the purchase page, or nothing while the build has none.
@MainActor
func openPurchasePage() {
    if let url = AppEdition.purchaseURL { NSWorkspace.shared.open(url) }
}
