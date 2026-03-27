import Combine
import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let palette: [Color] = [
        Color(red: 0.22, green: 0.88, blue: 0.40),  // 0: green
        Color(red: 0.18, green: 0.75, blue: 0.70),  // 1: teal
        Color(red: 0.30, green: 0.80, blue: 0.95),  // 2: cyan
        Color(red: 0.35, green: 0.55, blue: 1.00),  // 3: blue
        Color(red: 0.55, green: 0.40, blue: 1.00),  // 4: indigo
        Color(red: 0.75, green: 0.40, blue: 1.00),  // 5: purple
        Color(red: 1.00, green: 0.40, blue: 0.75),  // 6: pink
        Color(red: 1.00, green: 0.35, blue: 0.35),  // 7: red
        Color(red: 1.00, green: 0.50, blue: 0.22),  // 8: orange
        Color(red: 1.00, green: 0.85, blue: 0.25),  // 9: yellow
        Color(red: 1.0, green: 1.0, blue: 1.0),       // 10: white
    ]

    @Published var refreshIntervalSeconds: Double {
        didSet { defaults.set(refreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds) }
    }

    @Published var tintColorIndex: Int {
        didSet { defaults.set(tintColorIndex, forKey: Keys.tintColorIndex) }
    }

    @Published var accentColorIndex: Int {
        didSet { defaults.set(accentColorIndex, forKey: Keys.accentColorIndex) }
    }

    @Published var barWidth: Double {
        didSet { defaults.set(barWidth, forKey: Keys.barWidth) }
    }

    var tintColor: Color {
        Self.palette[tintColorIndex % Self.palette.count]
    }

    var accentColor: Color {
        Self.palette[accentColorIndex % Self.palette.count]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedInterval = defaults.object(forKey: Keys.refreshIntervalSeconds) as? Double ?? 120
        self.refreshIntervalSeconds = max(storedInterval, 60)
        self.tintColorIndex = defaults.object(forKey: Keys.tintColorIndex) as? Int ?? 0
        self.accentColorIndex = defaults.object(forKey: Keys.accentColorIndex) as? Int ?? 8
        self.barWidth = defaults.object(forKey: Keys.barWidth) as? Double ?? 24
    }

    private enum Keys {
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let tintColorIndex = "tintColorIndex"
        static let accentColorIndex = "accentColorIndex"
        static let barWidth = "barWidth"
    }
}
