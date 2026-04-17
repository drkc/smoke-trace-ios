import Foundation

struct StatsService {
    static func startOfDay(for date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    static func countInDay(for target: Date, logs: [SmokeLog], timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return logs.filter { calendar.isDate($0.createdAt, inSameDayAs: target) }.count
    }

    static func minutesSinceLast(for target: Date, logs: [SmokeLog]) -> Int? {
        guard let previous = logs
            .filter({ $0.createdAt < target })
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first else {
            return nil
        }
        let interval = target.timeIntervalSince(previous.createdAt)
        guard interval >= 0 else { return nil }
        return Int(interval / 60)
    }

    static func minutesFromNow(to lastDate: Date?) -> Int? {
        guard let lastDate else { return nil }
        let interval = Date().timeIntervalSince(lastDate)
        guard interval >= 0 else { return nil }
        return Int(interval / 60)
    }
}
