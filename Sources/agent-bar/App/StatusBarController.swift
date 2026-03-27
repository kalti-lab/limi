import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarCoordinator {
    private let controllers: [StatusBarController]

    init(store: UsageStore, providers: [ProviderKind]) {
        self.controllers = providers.map { StatusBarController(provider: $0, store: store, settings: AppContainer.shared.settings) }
        _ = controllers
    }
}

@MainActor
final class StatusBarController {
    private let provider: ProviderKind
    private let store: UsageStore
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: NSHostingController<AnyView>
    private var cancellables = Set<AnyCancellable>()

    init(provider: ProviderKind, store: UsageStore, settings: AppSettings) {
        self.provider = provider
        self.store = store
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.hostingController = NSHostingController(
            rootView: AnyView(
                ProviderPopoverContainerView(provider: provider)
                    .environmentObject(store)
                    .environmentObject(settings)
            )
        )
        configureStatusItem()
        configurePopover()
        subscribe()
        apply(snapshot: store.snapshot(for: provider))
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func subscribe() {
        store.$claudeSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self, self.provider == .claude else { return }
                self.apply(snapshot: snapshot)
            }
            .store(in: &cancellables)

        store.$codexSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self, self.provider == .codex else { return }
                self.apply(snapshot: snapshot)
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.apply(snapshot: self.store.snapshot(for: self.provider))
            }
            .store(in: &cancellables)
    }

    private func apply(snapshot: ProviderSnapshot) {
        guard let button = statusItem.button else { return }
        let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let rendered = StatusItemRenderer.render(snapshot: snapshot, settings: settings, isDark: isDark)
        statusItem.length = max(rendered.size.width, 28)
        button.image = rendered.image
        button.imagePosition = .imageOnly
        button.toolTip = "\(snapshot.provider.displayName) \(TokenFormatters.percentageString(for: snapshot.fiveHour.utilization))"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 320, height: 480)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private struct ProviderPopoverContainerView: View {
    let provider: ProviderKind

    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ProviderPopoverView(snapshot: store.snapshot(for: provider))
    }
}

@MainActor
private enum StatusItemRenderer {
    static func render(snapshot: ProviderSnapshot, settings: AppSettings, isDark: Bool) -> (image: NSImage, size: NSSize) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let rootView = MenuBarLabelView(snapshot: snapshot, isDark: isDark)
            .environmentObject(settings)
            .background(Color.clear)
        let hostingView = NSHostingView(rootView: rootView)
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        let pixelsWide = max(Int(size.width * scale), 1)
        let pixelsHigh = max(Int(size.height * scale), 1)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
        hostingView.displayIgnoringOpacity(hostingView.bounds, in: NSGraphicsContext.current!)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = false
        return (image, size)
    }
}
