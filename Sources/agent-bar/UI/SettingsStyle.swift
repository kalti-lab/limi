import SwiftUI

/// The one look every Settings tab shares: titled sections drawn like the
/// system's grouped form (a light rounded box on the window background, rows
/// inside it split by dividers), so the three tabs read as one app.
enum SettingsStyle {
    // The grouped form's section fill: about 3% darker than the window.
    static let sectionFill = Color.primary.opacity(0.035)
    static let cornerRadius: CGFloat = 10
    static let rowInsets = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    static let sectionSpacing: CGFloat = 20
}

/// A section title, aligned with the rows below it.
struct SettingsSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.headline).padding(.leading, SettingsStyle.rowInsets.leading) }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    let content: Content
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { SettingsSectionTitle(title) }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SettingsStyle.sectionFill,
                            in: RoundedRectangle(cornerRadius: SettingsStyle.cornerRadius, style: .continuous))
        }
    }
}

/// A row of a section. Rows after the first carry the divider above them, so
/// it moves with the row while rows are dragged.
struct SettingsRow<Content: View>: View {
    let divided: Bool
    let content: Content
    init(divided: Bool = false, @ViewBuilder content: () -> Content) {
        self.divided = divided
        self.content = content()
    }
    var body: some View {
        content
            .padding(SettingsStyle.rowInsets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                if divided { Divider().padding(.leading, SettingsStyle.rowInsets.leading) }
            }
    }
}

/// Hugs its child's ideal height up to a maximum; past it the child, a scroll
/// view, scrolls. The Settings window takes this height, so it fits each tab
/// instead of one fixed size that left two tabs half empty.
struct CappedHeight: Layout {
    var maximum: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let width = proposal.width ?? child.sizeThatFits(.unspecified).width
        let ideal = child.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return CGSize(width: width, height: min(ideal, maximum))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
