import Foundation
import ServiceManagement
import Testing
@testable import agent_bar

// Never the real login item: a test run must not change the Mac's login items.
private final class FakeLoginItem: LoginItem {
    var status: SMAppService.Status
    var failure: Error?
    var calls: [String] = []
    init(status: SMAppService.Status = .notRegistered) { self.status = status }
    func register() throws {
        calls.append("register")
        if let failure { throw failure }
        status = .enabled
    }
    func unregister() throws {
        calls.append("unregister")
        if let failure { throw failure }
        status = .notRegistered
    }
}

@MainActor
struct LaunchAtLoginTests {
    @Test func turningOnRegistersAndTurningOffUnregisters() {
        let item = FakeLoginItem()
        let model = LaunchAtLogin(item: item)
        #expect(!model.isOn)
        model.set(true)
        #expect(model.isOn && model.errorMessage == nil)
        model.set(false)
        #expect(!model.isOn)
        #expect(item.calls == ["register", "unregister"])
    }

    @Test func aFailedChangeStaysOffAndSaysWhy() {
        let item = FakeLoginItem()
        item.failure = CocoaError(.featureUnsupported)
        let model = LaunchAtLogin(item: item)
        model.set(true)
        #expect(!model.isOn)
        #expect(model.errorMessage?.hasPrefix("Could not change Open at Login") == true)
    }

    @Test func waitingForApprovalStaysOnAndAsksForIt() {
        let model = LaunchAtLogin(item: FakeLoginItem(status: .requiresApproval))
        #expect(model.isOn && model.needsApproval)
    }
}
