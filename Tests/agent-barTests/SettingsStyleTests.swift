import AppKit
import SwiftUI
import Testing
@testable import agent_bar

// Sizes are measured off screen; nothing is shown.
@MainActor
struct SettingsStyleTests {
    private func fittingHeight(content: CGFloat, maximum: CGFloat) -> CGFloat {
        let view = CappedHeight(maximum: maximum) {
            ScrollView { Color.clear.frame(height: content) }
        }.frame(width: 300)
        return NSHostingView(rootView: view).fittingSize.height
    }

    @Test func aShortTabHugsItsContent() {
        #expect(fittingHeight(content: 240, maximum: 600) == 240)
    }

    @Test func aLongTabStopsAtTheMaximumAndScrolls() {
        #expect(fittingHeight(content: 1_400, maximum: 600) == 600)
    }
}

// A window that is never shown: it checks that the Settings window follows its
// content's height when a tab changes, without any code resizing it.
private final class HeightModel: ObservableObject { @Published var height: CGFloat = 200 }
private struct HeightView: View {
    @ObservedObject var model: HeightModel
    var body: some View { Color.clear.frame(width: 300, height: model.height) }
}

@MainActor
struct SettingsWindowSizingTests {
    @Test func theWindowFollowsItsContentHeight() {
        let model = HeightModel()
        let controller = NSHostingController(rootView: HeightView(model: model))
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable]
        // Settings sizes the window once when it opens, as here; after that a
        // taller or shorter tab resizes it with no further code.
        window.setContentSize(controller.view.fittingSize)
        #expect(window.contentRect(forFrameRect: window.frame).height == 200)
        model.height = 420
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        window.layoutIfNeeded()
        #expect(window.contentRect(forFrameRect: window.frame).height == 420)
    }
}
