import Foundation

/// How a group's panel orders its accounts. Each group remembers its own; one that never chose lists them in its own order.
enum GroupListSort: String, Codable, CaseIterable, Identifiable {
    /// The group's own order, which dragging its chips in Settings or the rows of its list sets.
    case manual
    /// The account whose 5-hour limit refills first.
    case fiveHourReset
    /// The account whose weekly limit refills first: the service's own week, not a model's.
    case weeklyReset

    var id: String { rawValue }

    /// A choice this version does not know, as a later one may save, reads as manual instead of failing the whole file.
    init(from decoder: Decoder) throws {
        let value = try? decoder.singleValueContainer().decode(String.self)
        self = value.flatMap(Self.init(rawValue:)) ?? .manual
    }

    /// `ids`, given in the group's own order, in this order, by what each account's row shows (`snapshot`, nil for nothing):
    /// the soonest reset first. Ties keep the group's order. Accounts with nothing to go by, no value for the limit or no
    /// reset time for it, go last, in the group's order.
    func ordered(_ ids: [UUID], now: Date = .now, snapshot: (UUID) -> ProviderSnapshot?) -> [UUID] {
        guard self != .manual else { return ids }
        let keyed = ids.enumerated().map { place, id in
            (place: place, id: id, reset: snapshot(id).flatMap { soonestReset($0, now: now) })
        }
        return keyed.sorted { a, b in
            switch (a.reset, b.reset) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.place < b.place
            }
        }.map(\.id)
    }

    /// The soonest reset, to the nearest minute, among the row's limits this sort goes by: its 5-hour or its weekly one, or
    /// for Antigravity one of each per model group. One already past counts as `now`, since the row says "Resets soon" for
    /// any of them. Nil for manual, and when the row shows no such limit or no reset time for it.
    func soonestReset(_ snapshot: ProviderSnapshot, now: Date) -> Date? {
        guard let soonest = DisplayMetric.reported(snapshot).filter(goesBy).compactMap({ $0.window?.resetAt }).min() else { return nil }
        let minutes = (max(soonest, now).timeIntervalSinceReferenceDate / 60).rounded()
        return Date(timeIntervalSinceReferenceDate: minutes * 60)
    }

    // By the ids `DisplayMetric.all` gives: "5h" and "weekly", a model group's "…:5h" and "…:weekly". A model's own week,
    // "model:" and its name, counts for neither.
    private func goesBy(_ metric: DisplayMetric) -> Bool {
        let window: String
        switch self {
        case .manual: return false
        case .fiveHourReset: window = "5h"
        case .weeklyReset: window = "weekly"
        }
        return metric.id == window || metric.id.hasSuffix(":" + window)
    }
}

extension DisplayMetric {
    /// The limits a service reports a value for, in their usual order (5h, week, then each model's week): the cells of an
    /// account's row in a group's list, which shows "--" when there are none.
    static func reported(_ snapshot: ProviderSnapshot) -> [Self] {
        all(snapshot).filter { $0.window?.utilization != nil }
    }
}

extension MenuBarLayout {
    /// How the group's panel orders its accounts: manual for a group that never chose.
    var effectiveListSort: GroupListSort { listSort ?? .manual }
}

extension UsageStore {
    /// How a group's panel orders its accounts, nil for a group that does not exist.
    func listSort(for groupID: UUID) -> GroupListSort? {
        displayConfiguration.effectiveLayouts.first { $0.id == groupID }?.effectiveListSort
    }
    /// Remembers how a group's panel orders its accounts. Manual is saved as no choice, as for a group that never chose.
    func setListSort(_ sort: GroupListSort, for groupID: UUID) {
        guard let current = listSort(for: groupID), current != sort else { return }
        updateDisplay { $0.editLayout(groupID) { $0.listSort = sort == .manual ? nil : sort } }
    }
    /// The accounts a group's panel lists (`panelAccountIDs`), in the order of its sort by what their rows show now.
    func sortedPanelAccountIDs(for layout: MenuBarLayout, now: Date = .now) -> [UUID] {
        layout.effectiveListSort.ordered(panelAccountIDs(for: layout), now: now) { id in
            accounts.first { $0.id == id }.map { snapshot(for: $0) }
        }
    }
}
