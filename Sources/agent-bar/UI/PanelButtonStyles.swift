import SwiftUI

// Buttons in the menu bar panel show they are buttons when the pointer is over them, as in Control Center and menu
// bar menus: a light rounded background appears, darker while pressed. Without it the panel's icon and text buttons
// look like plain labels.
struct PanelButtonStyle: ButtonStyle {
    enum Kind {
        // An icon (refresh, settings): keeps its own colour, gets the background.
        case icon
        // Words (Accounts…, Quit, Open Log): grey until the pointer is over them, then full colour.
        case text
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        PanelButtonBody(configuration: configuration, kind: kind)
    }
}

private struct PanelButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: PanelButtonStyle.Kind
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind == .icon ? 6 : 5, style: .continuous)
        content
            .padding(kind == .icon ? EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
                                   : EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            .background(shape.fill(Color.primary.opacity(fill)))
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .icon: configuration.label
        case .text: configuration.label.foregroundStyle(hovering && isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
    }

    private var fill: Double {
        guard isEnabled else { return 0 }
        if configuration.isPressed { return 0.16 }
        return hovering ? 0.08 : 0
    }
}

// The panel's bordered buttons (Use in Claude Code, Set Up in Settings…, and the question's Cancel and Switch): a grey
// rounded fill like a small bordered button, a shade darker under the pointer and darker again while pressed. A blocked
// one keeps a fainter fill, so it still reads as a button that is there.
struct PanelBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PanelBorderedButtonBody(configuration: configuration)
    }
}

private struct PanelBorderedButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        configuration.label
            .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(shape.fill(Color.primary.opacity(fill)))
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var fill: Double {
        guard isEnabled else { return 0.05 }
        if configuration.isPressed { return 0.24 }
        return hovering ? 0.16 : 0.09
    }
}
