import Foundation
import Testing
@testable import agent_bar

@MainActor
struct GroupMemberTests {
    @Test func filesWithoutMembersReadAndSaveAsBefore() throws {
        let account = UUID(), group = UUID()
        let json = """
        {"version":2,"order":["\(account)"],"accounts":{"\(account)":{"badge":"CL","color":"blue"}},
         "layouts":[{"id":"\(group)","name":"Work","enabled":true,"style":"bars","showBadge":true,"showBar":true,
           "showPercent":true,"rowsPerColumn":3,"rows":[{"id":"line","accountID":"\(account)","metricID":"weekly","slot":0}]}]}
        """
        let config = try JSONDecoder().decode(DisplayConfiguration.self, from: Data(json.utf8))
        let layout = try #require(config.layouts?.first)
        #expect(layout.memberIDs == nil && layout.valid && config.valid)
        #expect(layout.effectiveMemberIDs == [account])
        #expect(!String(decoding: try JSONEncoder().encode(config), as: UTF8.self).contains("memberIDs"))

        // A store reading such a file leaves its groups as they were and saves them without the key.
        let f = try MemberFixture(); defer { f.close() }
        var file = f.store.displayConfiguration
        file.layouts = [MenuBarLayout(name: "Both", rows: [line(f.a, slot: 0), line(f.b, slot: 1)])]
        try f.files.write(file, to: f.path)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        #expect(reopened.displayConfiguration.layouts == file.layouts)
        #expect(try f.backups().isEmpty)
        #expect(!String(decoding: try Data(contentsOf: f.path), as: UTF8.self).contains("memberIDs"))
    }

    @Test func membersSurviveSavingAndReading() throws {
        let f = try MemberFixture(); defer { f.close() }
        let group = MenuBarLayout(name: "All", rows: [line(f.a, slot: 0)], memberIDs: [f.c.id, f.a.id, f.b.id])
        #expect(group.valid)
        f.store.updateDisplay { $0.layouts = [group] }
        #expect(f.store.displayConfiguration.layouts == [group] && f.store.displayConfiguration.valid)
        let decoded = try JSONDecoder().decode(DisplayConfiguration.self, from: JSONEncoder().encode(f.store.displayConfiguration))
        #expect(decoded.layouts == [group] && decoded.valid)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        #expect(reopened.displayConfiguration.layouts == [group])
        #expect(try f.backups().isEmpty)

        // Repeats, a missing line account, an empty list and an unknown account are each invalid.
        var broken = group
        for members in [[f.c.id, f.a.id, f.c.id], [f.c.id], []] {
            broken.memberIDs = members
            #expect(!broken.valid)
        }
        var config = f.store.displayConfiguration
        config.layouts = [MenuBarLayout(name: "Unknown", rows: [line(f.a, slot: 0)], memberIDs: [f.a.id, UUID()])]
        #expect(config.layouts?.first?.valid == true && !config.valid)
    }

    @Test func brokenMembersAreRepairedOnLoad() throws {
        let f = try MemberFixture(); defer { f.close() }
        var file = f.store.displayConfiguration
        file.layouts = [
            MenuBarLayout(name: "Repeats", rows: [line(f.a, slot: 0)], memberIDs: [f.a.id, f.b.id, f.a.id, UUID()]),
            MenuBarLayout(name: "Missing", rows: [line(f.b, slot: 0), line(f.c, slot: 1)], memberIDs: [f.b.id]),
            MenuBarLayout(name: "Empty", memberIDs: [])
        ]
        #expect(!file.valid)
        try f.files.write(file, to: f.path)
        let before = try Data(contentsOf: f.path)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        // Repaired, not replaced by the defaults.
        #expect(reopened.displayError == nil)
        let groups = try #require(reopened.displayConfiguration.layouts)
        #expect(groups.map(\.name) == ["Repeats", "Missing", "Empty"])
        #expect(groups.map(\.memberIDs) == [[f.a.id, f.b.id], [f.b.id, f.c.id], nil])
        #expect(reopened.displayConfiguration.valid)
        let backup = try #require(f.backups().first)
        #expect(try Data(contentsOf: backup) == before)
        #expect(try f.files.read(DisplayConfiguration.self, at: f.path).layouts == groups)
    }

    @Test func theFirstEditKeepsTheLineAccounts() throws {
        let f = try MemberFixture(); defer { f.close() }
        // An older file has no groups saved: each account shows as its own.
        #expect(f.store.displayConfiguration.layouts == nil)
        let own = try #require(f.store.displayConfiguration.effectiveLayouts.first { $0.rows.contains { $0.accountID == f.a.id } })
        #expect(own.memberIDs == nil && own.effectiveMemberIDs == [f.a.id])
        f.store.addGroupMember(f.c.id, to: own.id)
        let saved = try #require(f.store.displayConfiguration.layouts?.first { $0.id == own.id })
        #expect(saved.memberIDs == [f.a.id, f.c.id] && saved.rows.map(\.accountID) == [f.a.id])

        // The drawn lines' accounts come first, then the line Ring does not draw, then the new one, turned on.
        let ring = MenuBarLayout(name: "Ring", style: .ring, rows: [line(f.b, slot: 0), line(f.a, slot: 1), line(f.b, "5h", slot: 2)])
        #expect(ring.lineAccountIDs == [f.b.id] && ring.effectiveMemberIDs == [f.b.id, f.a.id])
        f.store.updateDisplay { $0.layouts = [ring]; $0.setVisible(f.c.id, false) }
        f.store.addGroupMember(f.c.id, to: ring.id)
        #expect(f.store.displayConfiguration.layouts?.first?.memberIDs == [f.b.id, f.a.id, f.c.id])
        #expect(f.store.displayConfiguration.isVisible(f.c.id))

        // One it holds already, or a group that is not there: nothing changes.
        let before = f.store.displayConfiguration
        f.store.addGroupMember(f.a.id, to: ring.id)
        f.store.addGroupMember(f.b.id, to: UUID())
        #expect(f.store.displayConfiguration == before)
    }

    @Test func removingAMemberRemovesItsLinesAndPercentage() throws {
        let f = try MemberFixture(); defer { f.close() }
        let a0 = line(f.a, slot: 0), b1 = line(f.b, slot: 1), a2 = line(f.a, "5h", slot: 2)
        let bars = MenuBarLayout(name: "Bars", percentageLineID: a2.id, rows: [a0, b1, a2], memberIDs: [f.a.id, f.b.id, f.c.id])
        let t0 = line(f.a, slot: 0), t1 = line(f.b, slot: 1), t2 = line(f.c, slot: 2)
        let text = MenuBarLayout(name: "Text", style: .text, rows: [t0, t1, t2])
        f.store.updateDisplay { $0.layouts = [bars, text] }

        f.store.removeGroupMember(f.a.id, from: bars.id)
        var groups = try #require(f.store.displayConfiguration.layouts)
        #expect(groups[0].memberIDs == [f.b.id, f.c.id])
        #expect(groups[0].rows.map(\.id) == [b1.id] && groups[0].rows.map(\.slot) == [1])
        #expect(groups[0].percentageLineID == nil && groups[0].effectivePercentageLineID == b1.id)

        // Text Only closes the gap. A group without members of its own starts from its lines' accounts.
        f.store.removeGroupMember(f.a.id, from: text.id)
        groups = try #require(f.store.displayConfiguration.layouts)
        #expect(groups[1].memberIDs == [f.b.id, f.c.id])
        #expect(groups[1].rows.map(\.id) == [t1.id, t2.id] && groups[1].rows.map(\.slot) == [0, 1])

        // Without its last member, a group goes back to using its lines' accounts, here none.
        f.store.removeGroupMember(f.b.id, from: bars.id)
        f.store.removeGroupMember(f.c.id, from: bars.id)
        groups = try #require(f.store.displayConfiguration.layouts)
        #expect(groups[0].memberIDs == nil && groups[0].rows.isEmpty)

        // Lines saved without slots keep where they were.
        var plain = MenuBarLayout(rows: [MenuBarLine(accountID: f.a.id, metricID: "weekly"), MenuBarLine(accountID: f.b.id, metricID: "weekly")])
        plain.removeMember(f.a.id)
        #expect(plain.rows.map(\.slot) == [1] && plain.memberIDs == [f.b.id] && plain.valid)
    }

    @Test func movingAMemberChangesOnlyTheOrder() throws {
        let f = try MemberFixture(); defer { f.close() }
        let group = MenuBarLayout(name: "All", rows: [line(f.a, slot: 0), line(f.b, slot: 1)], memberIDs: [f.a.id, f.b.id, f.c.id])
        f.store.updateDisplay { $0.layouts = [group] }
        // Down: after the target. Up: before it.
        #expect(f.store.moveGroupMember(f.a.id, to: f.c.id, in: group.id))
        var moved = try #require(f.store.displayConfiguration.layouts?.first)
        #expect(moved.memberIDs == [f.b.id, f.c.id, f.a.id])
        moved.memberIDs = group.memberIDs
        #expect(moved == group)
        #expect(f.store.moveGroupMember(f.a.id, to: f.b.id, in: group.id))
        #expect(f.store.displayConfiguration.layouts?.first?.memberIDs == [f.a.id, f.b.id, f.c.id])
        #expect(!f.store.moveGroupMember(f.a.id, to: f.a.id, in: group.id))
        #expect(!f.store.moveGroupMember(UUID(), to: f.a.id, in: group.id))

        // A group without members of its own gets them on the first real move, in the new order.
        let lines = MenuBarLayout(name: "Lines", rows: [line(f.a, slot: 0), line(f.b, slot: 1)])
        f.store.updateDisplay { $0.layouts = [lines] }
        #expect(!f.store.moveGroupMember(f.c.id, to: f.a.id, in: lines.id))
        #expect(f.store.displayConfiguration.layouts?.first?.memberIDs == nil)
        #expect(f.store.moveGroupMember(f.b.id, to: f.a.id, in: lines.id))
        let reordered = try #require(f.store.displayConfiguration.layouts?.first)
        #expect(reordered.memberIDs == [f.b.id, f.a.id] && reordered.rows == lines.rows)
    }

    @Test func everyGroupListsAllItsAccountsInItsOrder() throws {
        let leaving = UsageAccount(id: UUID(), provider: .codex, name: "Leaving", credentialID: UUID(), deletionPending: true)
        let f = try MemberFixture(more: [leaving]); defer { f.close() }
        // Without members of its own: its lines' accounts, each once, in the lines' order.
        let lines = MenuBarLayout(name: "Lines", rows: [line(f.b, slot: 0), line(f.a, slot: 1), line(f.b, "5h", slot: 2)])
        #expect(f.store.panelAccountIDs(for: lines) == [f.b.id, f.a.id])
        // Ring draws only its first line; its second line's account is listed too, as its chips show it.
        let ring = MenuBarLayout(name: "Ring", style: .ring, rows: [line(f.a, slot: 0), line(f.b, slot: 1)])
        #expect(f.store.panelAccountIDs(for: ring) == ring.effectiveMemberIDs && ring.effectiveMemberIDs == [f.a.id, f.b.id])
        // With members of its own: all of them in their order, whether the lines draw them or not.
        var group = lines
        group.memberIDs = [f.a.id, f.b.id]
        #expect(f.store.panelAccountIDs(for: group) == [f.a.id, f.b.id])
        group.memberIDs = [f.a.id, f.c.id, f.b.id]
        #expect(f.store.panelAccountIDs(for: group) == [f.a.id, f.c.id, f.b.id])
        // A group of one account lists that one.
        let single = MenuBarLayout(name: "One", rows: [line(f.c, slot: 0)])
        #expect(f.store.panelAccountIDs(for: single) == [f.c.id])
        // Hidden accounts and accounts being deleted are left out.
        f.store.updateDisplay { $0.setVisible(f.c.id, false) }
        group.memberIDs = [f.a.id, f.c.id, leaving.id, f.b.id]
        #expect(f.store.panelAccountIDs(for: group) == [f.a.id, f.b.id])
        #expect(f.store.panelAccountIDs(for: single).isEmpty)
        // No lines, only members.
        let membersOnly = MenuBarLayout(name: "Members", memberIDs: [f.b.id, f.a.id])
        #expect(f.store.panelAccountIDs(for: membersOnly) == [f.b.id, f.a.id])
        // Neither lines nor members: nothing to list, so a click opens Settings.
        #expect(f.store.panelAccountIDs(for: MenuBarLayout(name: "Empty")).isEmpty)
    }

    @Test func deletedAccountsLeaveGroupsAndNewOnesSkipGroupsWithMembers() throws {
        let a = UsageAccount(id: UUID(), provider: .claude, name: "A")
        let b = UsageAccount(id: UUID(), provider: .codex, name: "B")
        let c = UsageAccount(id: UUID(), provider: .claude, name: "C")
        var config = DisplayConfiguration(); config.sync([a, b])
        config.layouts = [
            MenuBarLayout(name: "Lines", rows: [MenuBarLine(accountID: a.id, metricID: "weekly")], memberIDs: [a.id, b.id]),
            MenuBarLayout(name: "Members", memberIDs: [b.id])
        ]
        // A new account gets a group of its own rather than a line in a group holding others.
        config.sync([a, b, c])
        #expect(config.layouts?.map(\.name) == ["Lines", "Members", "C"])
        #expect(config.layouts?[1].rows.isEmpty == true && config.layouts?[2].rows.map(\.accountID) == [c.id])
        #expect(config.valid)
        // A deleted account leaves its groups; a group left with none goes back to its lines' accounts.
        config.sync([a, c])
        #expect(config.layouts?.map(\.memberIDs) == [[a.id], nil, nil])
        #expect(config.valid)
        // That group is empty again, so the next new account fills it.
        let d = UsageAccount(id: UUID(), provider: .codex, name: "D")
        config.sync([a, c, d])
        #expect(config.layouts?.map(\.name) == ["Lines", "Members", "C"] && config.layouts?[1].rows.map(\.accountID) == [d.id])
        #expect(config.valid)

        // The store saves it: an account added since the file was written gets its own group.
        let f = try MemberFixture(); defer { f.close() }
        var file = f.store.displayConfiguration
        file.accounts[f.c.id.uuidString] = nil
        file.order.removeAll { $0 == f.c.id }
        file.layouts = [MenuBarLayout(name: "Members", memberIDs: [f.a.id, f.b.id])]
        try f.files.write(file, to: f.path)
        let reopened = f.reopened(); defer { reopened.shutdown() }
        let groups = try #require(reopened.displayConfiguration.layouts)
        #expect(groups.map(\.name) == ["Members", f.c.name] && groups[0].rows.isEmpty && groups[0].memberIDs == [f.a.id, f.b.id])
        #expect(groups[1].rows.map(\.accountID) == [f.c.id])
        #expect(try f.files.read(DisplayConfiguration.self, at: f.path).layouts == groups)
    }

    @Test func lineChoicesAreTheMembers() {
        let a = UUID(), b = UUID(), c = UUID(), gone = UUID()
        let ordered = [a, b, c]
        var group = MenuBarLayout(rows: [MenuBarLine(accountID: b, metricID: "weekly", slot: 0)])
        #expect(group.lineAccountChoices(ordered) == ordered)
        #expect(group.defaultLineAccount(ordered) == b)
        // The group's own accounts, in their order; one no longer listed is not offered.
        group.memberIDs = [c, gone, b]
        #expect(group.lineAccountChoices(ordered) == [c, b])
        #expect(group.defaultLineAccount(ordered) == b)
        group.rows.append(MenuBarLine(accountID: c, metricID: "5h", slot: 1))
        #expect(group.defaultLineAccount(ordered) == c)
        group.rows = []
        #expect(group.defaultLineAccount(ordered) == c)
        // The last line's account when it can be chosen, otherwise the first choice.
        let orphan = MenuBarLayout(rows: [MenuBarLine(accountID: gone, metricID: "weekly")])
        #expect(orphan.defaultLineAccount(ordered) == a)
        #expect(MenuBarLayout().defaultLineAccount([]) == nil)
    }

    @Test func membersOfShownGroupsAreRefreshed() throws {
        let f = try MemberFixture(); defer { f.close() }
        let shown = MenuBarLayout(name: "Shown", rows: [line(f.a, slot: 0)], memberIDs: [f.a.id, f.b.id])
        let off = MenuBarLayout(name: "Off", enabled: false, rows: [line(f.c, slot: 0)], memberIDs: [f.c.id])
        let blank = MenuBarLayout(name: "Blank", showPercent: false, memberIDs: [f.c.id])
        #expect(!blank.showsAnything)
        f.store.updateDisplay { $0.layouts = [shown, off, blank] }
        #expect(f.store.displayConfiguration.refreshAccountIDs == [f.a.id, f.b.id])
        #expect(f.store.refreshAccountIDs == [f.a.id, f.b.id])
        // A hidden member waits, as a hidden line does.
        f.store.updateDisplay { $0.setVisible(f.b.id, false) }
        #expect(f.store.refreshAccountIDs == [f.a.id])
        f.store.updateDisplay { $0.editLayout(off.id) { $0.enabled = true } }
        #expect(f.store.refreshAccountIDs == [f.a.id, f.c.id])
    }

    // Every account a group lists is refreshed, so no row of the list waits: Ring without members of its own draws only
    // its first line, and its second line's account is refreshed too.
    @Test func everyAccountAGroupListsIsRefreshed() throws {
        let f = try MemberFixture(); defer { f.close() }
        var ring = MenuBarLayout(name: "Ring", style: .ring, rows: [line(f.a, slot: 0), line(f.c, slot: 1)])
        f.store.updateDisplay { $0.layouts = [ring] }
        #expect(ring.memberIDs == nil && ring.displayedRows.map(\.accountID) == [f.a.id])
        #expect(f.store.panelAccountIDs(for: ring) == [f.a.id, f.c.id])
        #expect(f.store.refreshAccountIDs == [f.a.id, f.c.id])
        // The same once it holds them as its own.
        ring.memberIDs = ring.effectiveMemberIDs
        f.store.updateDisplay { $0.layouts = [ring] }
        #expect(f.store.refreshAccountIDs == [f.a.id, f.c.id])
        // A hidden account leaves the list and is not refreshed.
        f.store.updateDisplay { $0.setVisible(f.c.id, false) }
        #expect(f.store.panelAccountIDs(for: ring) == [f.a.id])
        #expect(f.store.refreshAccountIDs == [f.a.id])
        // A group switched off in the menu bar refreshes none of its accounts.
        f.store.updateDisplay { $0.setVisible(f.c.id, true); $0.editLayout(ring.id) { $0.enabled = false } }
        #expect(f.store.refreshAccountIDs.isEmpty)
    }
}

/// A line that already carries its badge, so reading a file does not change it.
private func line(_ account: UsageAccount, _ metric: String = "weekly", slot: Int) -> MenuBarLine {
    MenuBarLine(accountID: account.id, metricID: metric, slot: slot, badgeText: account.name)
}

@MainActor
private final class MemberFixture {
    let files = AccountFiles(root: FileManager.default.temporaryDirectory.appendingPathComponent("members-\(UUID())"))
    let suite = "members-\(UUID())"
    let defaults: UserDefaults
    let settings: AppSettings
    let a = UsageAccount(id: UUID(), provider: .claude, name: "Claude Work", credentialID: UUID())
    let b = UsageAccount(id: UUID(), provider: .codex, name: "Codex Personal", credentialID: UUID())
    let c = UsageAccount(id: UUID(), provider: .claude, name: "Claude Side", credentialID: UUID())
    let store: UsageStore
    var path: URL { files.root.appendingPathComponent("display-v2.json") }
    init(more: [UsageAccount] = []) throws {
        defaults = UserDefaults(suiteName: suite)!
        settings = AppSettings(defaults: defaults)
        var registry = AccountRegistry(accounts: [a, b, c] + more); registry.repairRepresentatives()
        try files.write(registry, to: files.registryURL)
        store = UsageStore(settings: settings, files: files, autoRefresh: false, loadAccount: { account, _ in
            ProviderSnapshot(provider: account.provider, updatedAt: .now, fiveHour: nil,
                weekly: WindowSummary(tokens: 40, limitTokens: 100, resetAt: nil, displayStyle: .percentage),
                modelWeeklies: [], planName: "Fixture", sourceDescription: "Fixture", note: nil, isStale: false, requiresLogin: false)
        })
    }
    /// Another store reading what has been saved, as the next launch does.
    func reopened() -> UsageStore { UsageStore(settings: settings, files: files, autoRefresh: false) }
    /// Copies of the display file taken when reading it repaired something.
    func backups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: files.root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("display-before-three-lines-") }
    }
    func close() { store.shutdown(); try? FileManager.default.removeItem(at: files.root); defaults.removePersistentDomain(forName: suite) }
}
