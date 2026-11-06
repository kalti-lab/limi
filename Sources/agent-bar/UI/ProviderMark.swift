import SwiftUI

/// A provider's mark on its own color, so accounts can be told apart at a glance.
struct ProviderMark: View {
    let provider: ProviderKind
    var size: CGFloat = 26
    var body: some View {
        Image(systemName: provider.symbolName)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AppTheme.tint(for: provider), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(provider.displayName)
    }
}
