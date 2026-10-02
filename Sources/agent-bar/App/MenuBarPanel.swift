import AppKit
import SwiftUI

// A menu-style window attached directly under a status item, like
// MenuBarExtra(.window): no popover arrow, system menu material, closes on
// outside click or Escape, and follows the SwiftUI content's size.
@MainActor
final class MenuBarPanel<Content: View> {
    private let panel: KeyablePanel
    private let host: ResizingHostingView<Content>
    private weak var anchor: NSStatusBarButton?
    private var monitors: [Any] = []

    var rootView: Content {
        get { host.rootView }
        set { host.rootView = newValue }
    }
    var isShown: Bool { panel.isVisible }

    init(rootView: Content) {
        host = ResizingHostingView(rootView: rootView)
        panel = KeyablePanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: true)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { panel.standardWindowButton($0)?.isHidden = true }
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let background = NSVisualEffectView()
        background.material = .menu
        background.blendingMode = .behindWindow
        background.state = .active
        host.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.topAnchor.constraint(equalTo: background.topAnchor),
            host.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        host.onSizeChange = { [weak self] in self?.layout() }
    }

    func show(below button: NSStatusBarButton) {
        anchor = button
        layout()
        panel.orderFrontRegardless()
        panel.makeKey()
        startMonitoring()
    }

    func close() {
        guard panel.isVisible else { return }
        stopMonitoring()
        panel.orderOut(nil)
    }

    private func layout() {
        guard let button = anchor, let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let size = host.fittingSize
        let height = min(size.height, visible.height - 8)
        let width = size.width
        // Left edges align with the status item; stay on screen near the right edge.
        let x = min(max(buttonFrame.minX, visible.minX + 4), visible.maxX - width - 4)
        let top = min(buttonFrame.minY - 1, visible.maxY)
        panel.setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: true)
    }

    private func startMonitoring() {
        stopMonitoring()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.close() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { close(); return nil } // Escape
                return event
            }
            // Clicks in other app windows (e.g. Settings) close the panel; the
            // status item's own click toggles it, so leave that one alone.
            if event.window !== panel && event.window !== anchor?.window { close() }
            return event
        }) { monitors.append(local) }
    }

    private func stopMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class ResizingHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }
}
