import AppKit
import Foundation
import Testing
@testable import agent_bar

@MainActor
struct MenuBarAppearanceTests {
    private func entries() -> [MenuBarEntry] {
        let a = UsageAccount(id: UUID(), provider: .claude, name: "Work")
        let b = UsageAccount(id: UUID(), provider: .codex, name: "Personal")
        return [a, b].enumerated().map { index, account in
            MenuBarEntry(account: account, display: AccountDisplay(badge: account.provider.shortName, color: index == 0 ? .blue : .purple),
                metric: DisplayMetric(id: "5h", title: "5-Hour Session", window: WindowSummary(tokens: 23 + index * 50, limitTokens: 100, resetAt: nil, displayStyle: .percentage)),
                stale: false, requiresLogin: false)
        }
    }

    // Opaque pixels darker than mid-grey (light menu bar) or lighter (dark menu bar).
    private func opaquePixels(_ image: NSImage, dark: Bool) -> Int {
        guard let rep = image.representations.first as? NSBitmapImageRep else { return 0 }
        var count = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.8 else { continue }
                let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
                if dark ? luminance > 0.8 : luminance < 0.2 { count += 1 }
            }
        }
        return count
    }

    @Test func textFollowsMenuBarAppearanceAndWidthStaysTheSame() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let output = ProcessInfo.processInfo.environment["AGENTBAR_QA_ARTIFACT_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for style in MenuBarStyle.allCases {
            var group = MenuBarLayout(name: "Team", style: style)
            group.badgeMode = .common; group.commonBadgeText = "AI"
            let config = group.renderingConfiguration(DisplayConfiguration())
            let onLight = DisplayStatusRenderer.render(entries: entries(), config: config, explicitRows: true, appearance: light)
            let onDark = DisplayStatusRenderer.render(entries: entries(), config: config, explicitRows: true, appearance: dark)
            #expect(onLight.size == onDark.size)
            if style != .capsule {
                // Capsule Fill keeps its own dark pill with white text.
                #expect(opaquePixels(onLight, dark: false) > 0, "\(style) has no dark text on a light menu bar")
                #expect(opaquePixels(onDark, dark: true) > 0, "\(style) has no light text on a dark menu bar")
            }
            if let output {
                for (name, image, background) in [("light", onLight, NSColor(white: 0.93, alpha: 1)), ("dark", onDark, NSColor(white: 0.16, alpha: 1))] {
                    let canvas = NSImage(size: NSSize(width: image.size.width + 12, height: image.size.height + 8), flipped: false) { rect in
                        background.setFill(); rect.fill()
                        image.draw(at: NSPoint(x: 6, y: 4), from: .zero, operation: .sourceOver, fraction: 1)
                        return true
                    }
                    if let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                        try rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("appearance-\(style.rawValue)-\(name).png"))
                    }
                }
            }
        }
    }

    @Test func gaugeSymbolStepsWithUsage() {
        #expect(DisplayStatusRenderer.gaugeSymbolName(for: nil) == "gauge.with.dots.needle.0percent")
        #expect(DisplayStatusRenderer.gaugeSymbolName(for: 0.19) == "gauge.with.dots.needle.0percent")
        #expect(DisplayStatusRenderer.gaugeSymbolName(for: 0.45) == "gauge.with.dots.needle.50percent")
        #expect(DisplayStatusRenderer.gaugeSymbolName(for: 0.95) == "gauge.with.dots.needle.100percent")
        for name in ["0percent", "33percent", "50percent", "67percent", "100percent"] {
            #expect(NSImage(systemSymbolName: "gauge.with.dots.needle." + name, accessibilityDescription: nil) != nil)
        }
    }
}
