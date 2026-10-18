import Foundation

public enum WaterUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case cups
    case milliliters

    public var id: String { rawValue }
    public var title: String { self == .cups ? "杯" : "mL" }

    public func format(_ value: Int) -> String {
        self == .cups ? "\(value) 杯" : "\(value) mL"
    }
}

public struct DailyGoal: Codable, Equatable, Sendable {
    public var value: Int
    public var unit: WaterUnit

    public init(value: Int = 8, unit: WaterUnit = .cups) {
        self.value = value
        self.unit = unit
    }

    public var isValid: Bool {
        (unit == .cups ? 1...100 : 50...20_000).contains(value)
    }

    public func milliliters(cupCapacity: Int) -> Int {
        unit == .cups ? value * cupCapacity : value
    }

    public func converted(to unit: WaterUnit, cupCapacity: Int) -> DailyGoal? {
        guard isValid, (10...2_000).contains(cupCapacity) else { return nil }
        if unit == self.unit { return self }
        let value = unit == .milliliters
            ? self.value * cupCapacity
            : (self.value + cupCapacity - 1) / cupCapacity
        let result = DailyGoal(value: value, unit: unit)
        return result.isValid ? result : nil
    }
}

public struct HydrationSettings: Codable, Equatable, Sendable {
    public var cupCapacityML: Int
    public var displayUnit: WaterUnit
    public var dailyGoal: DailyGoal

    public init(
        cupCapacityML: Int = 250,
        displayUnit: WaterUnit = .cups,
        dailyGoal: DailyGoal = DailyGoal()
    ) {
        self.cupCapacityML = cupCapacityML
        self.displayUnit = displayUnit
        self.dailyGoal = dailyGoal
    }

    public var isValid: Bool {
        (10...2_000).contains(cupCapacityML) && dailyGoal.isValid
    }
}

public struct DrinkEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let volumeML: Int

    public init(id: UUID = UUID(), timestamp: Date, volumeML: Int) {
        self.id = id
        self.timestamp = timestamp
        self.volumeML = volumeML
    }
}

public enum LocalDay {
    public static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func key(for date: Date, calendar: Calendar = calendar()) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(for key: String, calendar: Calendar = calendar()) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self.key(for: date, calendar: calendar) == key else { return nil }
        return date
    }
}

public struct DayRecord: Codable, Equatable, Identifiable, Sendable {
    public let dayKey: String
    public var goal: DailyGoal
    public var goalCupCapacityML: Int
    public var drinks: [DrinkEntry]

    public var id: String { dayKey }
    public var cupCount: Int { drinks.count }
    public var totalML: Int { drinks.reduce(0) { $0 + $1.volumeML } }
    public var goalML: Int { goal.milliliters(cupCapacity: goalCupCapacityML) }
    public var goalCurrentValue: Int { goal.unit == .cups ? cupCount : totalML }
    public var progress: Double { Double(goalCurrentValue) / Double(max(goal.value, 1)) }
    public var isGoalReached: Bool { goalCurrentValue >= goal.value }

    public init(dayKey: String, settings: HydrationSettings, drinks: [DrinkEntry] = []) {
        self.dayKey = dayKey
        self.goal = settings.dailyGoal
        self.goalCupCapacityML = settings.cupCapacityML
        self.drinks = drinks
    }

    public func amount(in unit: WaterUnit) -> Int {
        unit == .cups ? cupCount : totalML
    }

    public func goalAmount(in unit: WaterUnit) -> Double {
        if unit == goal.unit { return Double(goal.value) }
        return unit == .milliliters
            ? Double(goalML)
            : Double(goal.value) / Double(max(goalCupCapacityML, 1))
    }
}

public struct HydrationDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var settings: HydrationSettings
    public var days: [DayRecord]

    public init(settings: HydrationSettings = HydrationSettings(), days: [DayRecord] = []) {
        self.version = 1
        self.settings = settings
        self.days = days
    }

    public func day(on date: Date, calendar: Calendar = LocalDay.calendar()) -> DayRecord {
        let key = LocalDay.key(for: date, calendar: calendar)
        return days.first { $0.dayKey == key } ?? DayRecord(dayKey: key, settings: settings)
    }

    public mutating func addCup(at date: Date, calendar: Calendar = LocalDay.calendar()) {
        let key = LocalDay.key(for: date, calendar: calendar)
        let entry = DrinkEntry(timestamp: date, volumeML: settings.cupCapacityML)
        if let index = days.firstIndex(where: { $0.dayKey == key }) {
            days[index].drinks.append(entry)
        } else {
            days.append(DayRecord(dayKey: key, settings: settings, drinks: [entry]))
        }
    }

    @discardableResult
    public mutating func removeLastCup(on date: Date, calendar: Calendar = LocalDay.calendar()) -> Bool {
        let key = LocalDay.key(for: date, calendar: calendar)
        guard let index = days.firstIndex(where: { $0.dayKey == key }),
              !days[index].drinks.isEmpty else { return false }
        // Append order survives equal timestamps and clock adjustments, unlike a timestamp maximum.
        days[index].drinks.removeLast()
        return true
    }

    @discardableResult
    public mutating func removeDrink(id: UUID, dayKey: String) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.dayKey == dayKey }),
              let entryIndex = days[dayIndex].drinks.firstIndex(where: { $0.id == id }) else { return false }
        days[dayIndex].drinks.remove(at: entryIndex)
        return true
    }

    public mutating func updateSettings(_ settings: HydrationSettings, at date: Date, calendar: Calendar = LocalDay.calendar()) throws {
        guard settings.isValid else { throw HydrationDataError.invalidSettings }
        self.settings = settings
        // Today's target follows settings; earlier targets and recorded volumes remain unchanged.
        let key = LocalDay.key(for: date, calendar: calendar)
        if let index = days.firstIndex(where: { $0.dayKey == key }) {
            days[index].goal = settings.dailyGoal
            days[index].goalCupCapacityML = settings.cupCapacityML
        }
    }

    public func recentDays(ending date: Date, count: Int = 7, calendar: Calendar = LocalDay.calendar()) -> [DayRecord] {
        guard count > 0 else { return [] }
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return day(on: date, calendar: calendar)
        }
    }

    public func validate() throws {
        guard version == 1 else { throw HydrationDataError.unsupportedVersion(version) }
        guard settings.isValid else { throw HydrationDataError.invalidSettings }
        var dayKeys = Set<String>()
        var entryIDs = Set<UUID>()
        for day in days {
            guard LocalDay.date(for: day.dayKey) != nil,
                  dayKeys.insert(day.dayKey).inserted,
                  day.goal.isValid,
                  (10...2_000).contains(day.goalCupCapacityML) else { throw HydrationDataError.invalidRecords }
            for entry in day.drinks {
                guard (10...2_000).contains(entry.volumeML),
                      entry.timestamp.timeIntervalSince1970.isFinite,
                      entryIDs.insert(entry.id).inserted else { throw HydrationDataError.invalidRecords }
            }
        }
    }
}

public enum HydrationDataError: LocalizedError {
    case invalidSettings
    case invalidRecords
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidSettings: "杯容量或每日目标不在有效范围内。"
        case .invalidRecords: "饮水记录格式异常。为保护原始数据，暂时无法写入。"
        case .unsupportedVersion(let version): "数据版本 \(version) 暂不支持，请使用更新版本的应用。"
        }
    }
}
