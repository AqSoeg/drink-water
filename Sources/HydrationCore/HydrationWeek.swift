import Foundation

public struct HydrationWeek: Equatable, Sendable {
    public let days: [DayRecord]
    public let elapsedDayCount: Int

    public var recordedDayCount: Int { elapsedDays.filter { $0.cupCount > 0 }.count }
    public var goalReachedDayCount: Int { elapsedDays.filter(\.isGoalReached).count }

    private var elapsedDays: ArraySlice<DayRecord> { days.prefix(elapsedDayCount) }

    public func dailyAverage(in unit: WaterUnit) -> Double {
        guard elapsedDayCount > 0 else { return 0 }
        return Double(elapsedDays.reduce(0) { $0 + $1.amount(in: unit) }) / Double(elapsedDayCount)
    }
}

extension LocalDay {
    public static func startOfWeek(for date: Date, calendar: Calendar = calendar()) -> Date {
        let day = calendar.startOfDay(for: date)
        // Gregorian weekday is Sunday = 1; our weeks always begin on Monday.
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }
}

extension HydrationDocument {
    public func week(containing date: Date, asOf today: Date, calendar: Calendar = LocalDay.calendar()) -> HydrationWeek {
        let start = LocalDay.startOfWeek(for: date, calendar: calendar)
        let days = (0..<7).compactMap { offset -> DayRecord? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return day(on: date, calendar: calendar)
        }
        let elapsed = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: today)).day ?? 0
        return HydrationWeek(days: days, elapsedDayCount: min(max(elapsed + 1, 0), days.count))
    }

    public func availableWeekCount(asOf today: Date, calendar: Calendar = LocalDay.calendar()) -> Int {
        let todayKey = LocalDay.key(for: today, calendar: calendar)
        guard let first = days.filter({ !$0.drinks.isEmpty && $0.dayKey <= todayKey }).map(\.dayKey).min(),
              let date = LocalDay.date(for: first, calendar: calendar) else { return 1 }
        let start = LocalDay.startOfWeek(for: date, calendar: calendar)
        let current = LocalDay.startOfWeek(for: today, calendar: calendar)
        let distance = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        // Empty weeks between records remain reachable; stop at the oldest recorded week.
        return max(distance / 7 + 1, 1)
    }
}
