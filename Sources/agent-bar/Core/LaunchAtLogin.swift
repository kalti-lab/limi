import Foundation
import ServiceManagement

/// The login item behind Settings › General › Open at Login.
protocol LoginItem {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItem {}

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isOn = false
    @Published private(set) var needsApproval = false
    @Published private(set) var errorMessage: String?
    private let item: LoginItem

    init(item: LoginItem = SMAppService.mainApp) {
        self.item = item
        refresh()
    }

    func refresh() {
        // Registered but waiting for approval stays on, where the person put it.
        isOn = item.status == .enabled || item.status == .requiresApproval
        needsApproval = item.status == .requiresApproval
    }

    func set(_ on: Bool) {
        errorMessage = nil
        do {
            if on { try item.register() } else { try item.unregister() }
        } catch {
            errorMessage = String(localized: "Could not change Open at Login: \(error.localizedDescription)")
        }
        refresh()
    }

    func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
