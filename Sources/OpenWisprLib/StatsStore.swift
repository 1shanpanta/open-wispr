import Foundation

struct DailyEntry: Codable {
    let date: String
    var words: Int
}

struct Stats: Codable {
    var totalWords: Int
    var dailyHistory: [DailyEntry]

    static let empty = Stats(totalWords: 0, dailyHistory: [])
}

public class StatsStore {
    private static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/open-wispr")
    static let statsFile = configDir.appendingPathComponent("stats.json")

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func load() -> Stats {
        guard let data = try? Data(contentsOf: statsFile),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else {
            return .empty
        }
        return stats
    }

    static func save(_ stats: Stats) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: statsFile, options: .atomic)
    }

    public static func logWords(_ count: Int) {
        guard count > 0 else { return }
        var stats = load()
        let today = dateFormatter.string(from: Date())

        stats.totalWords += count

        if let lastIndex = stats.dailyHistory.lastIndex(where: { $0.date == today }) {
            stats.dailyHistory[lastIndex].words += count
        } else {
            stats.dailyHistory.append(DailyEntry(date: today, words: count))
        }

        // Keep last 90 days of history
        if stats.dailyHistory.count > 90 {
            stats.dailyHistory = Array(stats.dailyHistory.suffix(90))
        }

        save(stats)
    }

    public static func todayWords() -> Int {
        let stats = load()
        let today = dateFormatter.string(from: Date())
        return stats.dailyHistory.first(where: { $0.date == today })?.words ?? 0
    }

    public static func thisWeekWords() -> Int {
        let stats = load()
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }
        let weekStartStr = dateFormatter.string(from: weekStart)
        return stats.dailyHistory
            .filter { $0.date >= weekStartStr }
            .reduce(0) { $0 + $1.words }
    }

    public static func allTimeWords() -> Int {
        return load().totalWords
    }
}
