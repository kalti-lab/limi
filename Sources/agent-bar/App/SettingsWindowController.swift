import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    var presentationWindow: NSWindow {
        if window == nil { show(tab: .accounts) }
        return window!
    }
    func show(tab: SettingsTab = .accounts, groupID: UUID? = nil) {
        let container = AppContainer.shared
        if let groupID { container.store.selectMenuBarGroup(groupID) }
        let view = SettingsView(tab: tab).environmentObject(container.settings).environmentObject(container.store)
        let controller = NSHostingController(rootView: view)
        let wasOpen = window?.isVisible == true
        if window == nil {
            let created = NSWindow(contentViewController: controller)
            created.styleMask = [.titled, .closable, .miniaturizable]
            created.isReleasedWhenClosed = false
            window = created
        } else { window?.contentViewController = controller }
        window?.title = "AgentBar — Settings"
        window?.setContentSize(NSSize(width: 540, height: 660))
        // Place only after sizing: centering the still-unsized window left its
        // top-left corner under the menu bar. An open window stays where it is.
        if !wasOpen, let window, let area = Self.screenUnderPointer()?.visibleFrame {
            window.setFrameOrigin(Self.centeredOrigin(of: window.frame.size, in: area))
        }
        SettingsWindowPresenter(
            activateApplication: { NSApplication.shared.activate(ignoringOtherApps: true) },
            openSettings: { self.window?.makeKeyAndOrderFront(nil) }
        ).present()
    }

    /// The display whose menu bar opened Settings.
    private static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }

    /// Centers a window in the area the menu bar and Dock leave free. On a
    /// smaller area the top-left stays inside, so the title bar remains reachable.
    nonisolated static func centeredOrigin(of size: NSSize, in area: NSRect) -> NSPoint {
        NSPoint(x: max(area.minX, min((area.midX - size.width / 2).rounded(), area.maxX - size.width)),
                y: min(area.maxY - size.height, max(area.minY, (area.midY - size.height / 2).rounded())))
    }
}
