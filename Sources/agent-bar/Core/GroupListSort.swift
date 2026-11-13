import Foundation

/// How a group's panel orders its accounts. Each group remembers its own; one that never chose lists them in its own order.
enum GroupListSort: String, Codable, CaseIterable, Identifiable {
    /// The group's own order, which dragging its chips in Settings or the rows of its list sets.
    case manual
    /// The account nearest a limit first: by the highest percentage among the limits its row shows.
    case usage
    /// The account with a limit that refills first: by the soonest reset among the limits its row shows.
    case resetTime

    var id: String { rawValue }

    /// A choice this version does not know, as a later one may save, reads as manual instead of failing the whole file.
    init(from decoder: Decoder) throws {
        let value = try? decoder.singleValueContainer().decode(String.self)
        self = value.flatMap(Self.init(rawValue:)) ?? .manual
    }

    /// `ids`, given in the group's own order, in this order, by what each account's row shows (`snapshot`, nil for nothing).
    /// Ties keep the group's order. Accounts with nothing to go by, a row of "--" or one without a reset time, go last,
    /// in the group's order.
    func ordered(_ ids: [UUID], now: Date = .now, snapshot: (UUID) -> ProviderSnapshot?) -> [UUID] {
        switch self {
        case .manual: return ids
        case .usage: return Self.ordered(ids, descending: true) { snapshot($0).flatMap(Self.highestPercent) }
        case .resetTime: return Self.ordered(ids, descending: false) { snapshot($0).flatMap { Self.soonestReset($0, now: now) } }
        }
    }

    /// The highest percentage among the limits a row shows, whole as the row shows it; nil when it shows none ("--").
    static func highestPercent(_ snapshot: ProviderSnapshot) -> Int? {
        DisplayMetric.reported(snapshot).compactMap { $0.window?.utilization }.map { Int(($0 * 100).rounded()) }.max()
    }

    /// The soonest reset among the limits a row shows, to the nearest minute. One already past counts as `now`, since the
    /// row says "Resets soon" for any of them. Nil when the row shows no reset time.
    static func soonestReset(_ snapshot: ProviderSnapshot, now: Date) -> Date? {
        guard let soonest = DisplayMetric.reported(snapshot).compactMap({ $0.window?.resetAt }).min() else { return nil }
        let minutes = (max(soonest, now).timeIntervalSinceReferenceDate / 60).rounded()
        return Date(timeIntervalSinceReferenceDate: minutes * 60)
    }

    // Accounts with a key first, by key; equal keys, and the accounts without one, keep their places.
    private static func ordered<Key: Comparable>(_ ids: [UUID], descending: Bool, key: (UUID) -> Key?) -> [UUID] {
        let keyed = ids.enumerated().map { (place: $0.offset, id: $0.element, key: key($0.element)) }
        return keyed.sorted { a, b in
            switch (a.key, b.key) {
            case let (x?, y?) where x != y: return descending ? x > y : x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.place < b.place
            }
        }.map(\.id)
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
