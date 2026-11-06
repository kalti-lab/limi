import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var resizeObserver: NSObjectProtocol?
    var presentationWindow: NSWindow {
        if window == nil { show(tab: .accounts) }
        return window!
    }
    func show(tab: SettingsTab = .accounts, groupID: UUID? = nil) {
        let container = AppContainer.shared
        if let groupID { container.store.selectMenuBarGroup(groupID) }
        let wasOpen = window?.isVisible == true
        // An open window stays on its display; a new one opens where the pointer is.
        let screen = (wasOpen ? window?.screen : nil) ?? Self.screenUnderPointer()
        let view = SettingsView(tab: tab, maxContentHeight: Self.maxContentHeight(in: screen?.visibleFrame))
            .environmentObject(container.settings).environmentObject(container.store)
        let controller = NSHostingController(rootView: view)
        if window == nil {
            let created = NSWindow(contentViewController: controller)
            created.styleMask = [.titled, .closable, .miniaturizable]
            created.isReleasedWhenClosed = false
            window = created
            // A taller tab grows the window downward; keep it above the Dock.
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: created, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keepOnScreen() }
            }
        } else { window?.contentViewController = controller }
        window?.title = String(localized: "\(AppInfo.name) — Settings")
        // The window fits the tab it opens on; switching tabs resizes it from there.
        window?.setContentSize(controller.view.fittingSize)
        // Place only after sizing: centering the still-unsized window left its
        // top-left corner under the menu bar. An open window stays where it is.
        if !wasOpen, let window, let area = screen?.visibleFrame {
            window.setFrameOrigin(Self.centeredOrigin(of: window.frame.size, in: area))
        } else {
            keepOnScreen()
        }
        SettingsWindowPresenter(
            activateApplication: { NSApplication.shared.activate(ignoringOtherApps: true) },
            openSettings: { self.window?.makeKeyAndOrderFront(nil) }
        ).present()
    }

    /// Room for a tab's content on a display: its free height less the title
    /// bar, tab picker and a banner, so the whole window stays on screen.
    nonisolated static func maxContentHeight(in area: NSRect?) -> CGFloat {
        max(300, (area?.height ?? 860) - 160)
    }

    /// Moves a window that grew below the Dock back up, keeping its title bar
    /// on screen when it is taller than the display.
    private func keepOnScreen() {
        guard let window, let area = window.screen?.visibleFrame, window.frame.minY < area.minY else { return }
        var frame = window.frame
        frame.origin.y = min(area.minY, area.maxY - frame.height)
        window.setFrame(frame, display: true)
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
