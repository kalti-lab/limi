import AppKit
import Testing
@testable import agent_bar

struct SettingsWindowPlacementTests {
    @Test
    func opensExactlyCenteredInTheAreaTheMenuBarAndDockLeave() {
        let window = NSSize(width: 540, height: 692)
        // The three displays this was reported on, in AppKit coordinates:
        // the main one with its menu bar and Dock, the built-in one to its
        // left, and a portrait one to its right.
        #expect(SettingsWindowController.centeredOrigin(of: window, in: NSRect(x: 0, y: 90, width: 2560, height: 1320))
            == NSPoint(x: 1010, y: 404))
        #expect(SettingsWindowController.centeredOrigin(of: window, in: NSRect(x: -1728, y: 0, width: 1728, height: 1085))
            == NSPoint(x: -1134, y: 197))
        #expect(SettingsWindowController.centeredOrigin(of: window, in: NSRect(x: 2560, y: -906, width: 1440, height: 2560))
            == NSPoint(x: 3010, y: 28))
    }

    @Test
    func keepsTheTitleBarReachableOnAnAreaSmallerThanTheWindow() {
        let origin = SettingsWindowController.centeredOrigin(of: NSSize(width: 540, height: 692),
                                                             in: NSRect(x: 0, y: 0, width: 500, height: 600))
        #expect(origin.x == 0)
        #expect(origin.y + 692 == 600)
    }
}
