import Foundation
import Testing
@testable import HydrationCore

private let calendar = LocalDay.calendar(timeZone: TimeZone(secondsFromGMT: 8 * 3_600)!)

private func date(_ day: Int = 15, hour: Int = 12, minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

@Test func addCupIncrementsCountAndVolume() {
    var document = HydrationDocument()
    for _ in 0..<3 { document.addCup(at: date(), calendar: calendar) }
    let day = document.day(on: date(), calendar: calendar)
    #expect(day.cupCount == 3)
    #expect(day.totalML == 750)
    #expect(day.progress == 0.375)
}

@Test func changedCupCapacityDoesNotRewriteOldDrinks() throws {
    var document = HydrationDocument()
    document.addCup(at: date(), calendar: calendar)
    var settings = document.settings
    settings.cupCapacityML = 180
    try document.updateSettings(settings, at: date(), calendar: calendar)
    document.addCup(at: date(hour: 13), calendar: calendar)
    let day = document.day(on: date(), calendar: calendar)
    #expect(day.cupCount == 2)
    #expect(day.totalML == 430)
    #expect(day.drinks.map(\.volumeML) == [250, 180])
}

@Test func goalUnitConversionValidatesBothInputAndOutput() {
    #expect(DailyGoal().converted(to: .milliliters, cupCapacity: 180) == DailyGoal(value: 1_440, unit: .milliliters))
    #expect(DailyGoal(value: 1_440, unit: .milliliters).converted(to: .cups, cupCapacity: 180) == DailyGoal(value: 8))
    #expect(DailyGoal(value: 20, unit: .milliliters).converted(to: .cups, cupCapacity: 250) == nil)
    #expect(DailyGoal(value: 100).converted(to: .milliliters, cupCapacity: 2_000) == nil)
    #expect(DailyGoal(value: 1).converted(to: .milliliters, cupCapacity: 10) == nil)
    #expect(DailyGoal(value: 20_000, unit: .milliliters).converted(to: .cups, cupCapacity: 10) == nil)
    #expect(DailyGoal().converted(to: .milliliters, cupCapacity: 0) == nil)
}

@Test func goalDisplayConvertsWithoutChangingTheStoredGoal() {
    let day = DayRecord(dayKey: "2026-10-15", settings: HydrationSettings(), drinks: [
        DrinkEntry(timestamp: date(), volumeML: 250)
    ])
    #expect(day.amount(in: .cups) == 1)
    #expect(day.goalAmount(in: .cups) == 8)
    #expect(day.amount(in: .milliliters) == 250)
    #expect(day.goalAmount(in: .milliliters) == 2_000)
    #expect(day.goal == DailyGoal())
    #expect(day.progress == 0.125)
}

@Test func milliliterGoalDisplayKeepsFractionalCupTargets() {
    let day = DayRecord(dayKey: "2026-10-15", settings: HydrationSettings(
        cupCapacityML: 250, dailyGoal: DailyGoal(value: 900, unit: .milliliters)
    ))
    #expect(day.goalAmount(in: .milliliters) == 900)
    #expect(day.goalAmount(in: .cups) == 3.6)
    #expect(day.goal == DailyGoal(value: 900, unit: .milliliters))
}

@Test func historicalGoalDisplayUsesItsSavedCapacity() throws {
    var document = HydrationDocument()
    document.addCup(at: date(14), calendar: calendar)
    try document.updateSettings(HydrationSettings(cupCapacityML: 180), at: date(), calendar: calendar)
    #expect(document.day(on: date(14), calendar: calendar).goalAmount(in: .milliliters) == 2_000)
    #expect(document.day(on: date(), calendar: calendar).goalAmount(in: .milliliters) == 1_440)
}

@Test func midnightStartsANewDayWithoutDeletingHistory() {
    var document = HydrationDocument()
    document.addCup(at: date(hour: 23, minute: 59), calendar: calendar)
    #expect(document.day(on: date(16, hour: 0), calendar: calendar).cupCount == 0)
    document.addCup(at: date(16, hour: 0), calendar: calendar)
    #expect(document.days.count == 2)
    #expect(document.day(on: date(), calendar: calendar).cupCount == 1)
}

@Test func milliliterGoalUsesRecordedVolume() throws {
    var document = HydrationDocument()
    try document.updateSettings(HydrationSettings(cupCapacityML: 180, dailyGoal: DailyGoal(value: 900, unit: .milliliters)), at: date(), calendar: calendar)
    for _ in 0..<5 { document.addCup(at: date(), calendar: calendar) }
    let day = document.day(on: date(), calendar: calendar)
    #expect(day.totalML == 900)
    #expect(day.goalCurrentValue == 900)
    #expect(day.progress == 1)
    #expect(day.isGoalReached)
}

@Test func pastGoalsRemainUnchangedAfterSettingsUpdate() throws {
    var document = HydrationDocument()
    document.addCup(at: date(14), calendar: calendar)
    document.addCup(at: date(), calendar: calendar)
    try document.updateSettings(HydrationSettings(cupCapacityML: 300, dailyGoal: DailyGoal(value: 1_800, unit: .milliliters)), at: date(), calendar: calendar)
    let yesterday = document.day(on: date(14), calendar: calendar)
    #expect(yesterday.goal == DailyGoal())
    #expect(yesterday.goalCupCapacityML == 250)
    #expect(document.day(on: date(), calendar: calendar).goal.value == 1_800)
}

@Test func undoNeverMakesCountNegativeAndCannotRemoveYesterday() {
    var document = HydrationDocument()
    document.addCup(at: date(14), calendar: calendar)
    let removedYesterday = document.removeLastCup(on: date(), calendar: calendar)
    #expect(!removedYesterday)
    document.addCup(at: date(), calendar: calendar)
    let removedToday = document.removeLastCup(on: date(), calendar: calendar)
    #expect(removedToday)
    let removedEmpty = document.removeLastCup(on: date(), calendar: calendar)
    #expect(!removedEmpty)
    #expect(document.day(on: date(), calendar: calendar).totalML == 0)
    #expect(document.day(on: date(14), calendar: calendar).cupCount == 1)
}

@Test func deleteSpecificEntryOnlyTouchesSelectedRecord() {
    var document = HydrationDocument()
    document.addCup(at: date(14), calendar: calendar)
    document.addCup(at: date(), calendar: calendar)
    let entry = document.days[0].drinks[0]
    let removed = document.removeDrink(id: entry.id, dayKey: "2026-10-14")
    #expect(removed)
    #expect(document.day(on: date(), calendar: calendar).cupCount == 1)
    #expect(document.day(on: date(14), calendar: calendar).cupCount == 0)
}

@Test func recentWeekIncludesEmptyDaysInChronologicalOrder() {
    var document = HydrationDocument()
    document.addCup(at: date(13), calendar: calendar)
    let week = document.recentDays(ending: date(), calendar: calendar)
    #expect(week.count == 7)
    #expect(week.first?.dayKey == "2026-10-09")
    #expect(week.last?.dayKey == "2026-10-15")
    #expect(week.map(\.cupCount) == [0, 0, 0, 0, 1, 0, 0])
    #expect(document.recentDays(ending: date(), count: 0).isEmpty)
}

@Test func progressCanExceedTargetWithoutClampingRecordedAmount() {
    var document = HydrationDocument(settings: HydrationSettings(dailyGoal: DailyGoal(value: 1)))
    document.addCup(at: date(), calendar: calendar)
    document.addCup(at: date(), calendar: calendar)
    #expect(document.day(on: date(), calendar: calendar).progress == 2)
    #expect(document.day(on: date(), calendar: calendar).cupCount == 2)
}

@Test func invalidSettingsAreRejectedWithoutChangingData() throws {
    var document = HydrationDocument()
    let original = document
    #expect(throws: HydrationDataError.self) {
        try document.updateSettings(HydrationSettings(cupCapacityML: 0), at: date())
    }
    #expect(document == original)
    #expect(!DailyGoal(value: 0).isValid)
    #expect(!DailyGoal(value: 20_001, unit: .milliliters).isValid)
}

@Test func storageRoundTripAndMissingFileDefaults() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = HydrationRepository(fileURL: directory.appendingPathComponent("hydration.json"))
    #expect(try repository.load() == HydrationDocument())
    var document = HydrationDocument()
    document.addCup(at: date(), calendar: calendar)
    try repository.save(document)
    #expect(try repository.load() == document)
}

@Test func corruptFileIsNotTreatedAsEmptyHistory() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("hydration.json")
    let corrupt = Data("not valid json".utf8)
    try corrupt.write(to: url)
    let repository = HydrationRepository(fileURL: url)
    #expect(throws: (any Error).self) { try repository.load() }
    #expect(try Data(contentsOf: url) == corrupt)
}

@Test func validatesDuplicatesAndUnknownVersions() throws {
    var document = HydrationDocument()
    document.addCup(at: date(), calendar: calendar)
    document.days.append(document.days[0])
    #expect(throws: HydrationDataError.self) { try document.validate() }
    document = HydrationDocument()
    document.version = 99
    #expect(throws: HydrationDataError.self) { try document.validate() }
}

@Test func undoUsesAppendOrderWhenTheClockMovesBackwards() throws {
    var document = HydrationDocument()
    document.addCup(at: date(hour: 14), calendar: calendar)
    try document.updateSettings(HydrationSettings(cupCapacityML: 180), at: date(hour: 13), calendar: calendar)
    document.addCup(at: date(hour: 13), calendar: calendar)
    let removed = document.removeLastCup(on: date(), calendar: calendar)
    #expect(removed)
    #expect(document.day(on: date(), calendar: calendar).totalML == 250)
}

@Test func undoAfterReloadRemovesLastAddedCupWithIdenticalTimestamps() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = HydrationRepository(fileURL: directory.appendingPathComponent("hydration.json"))
    var document = HydrationDocument()
    document.addCup(at: date().addingTimeInterval(0.1), calendar: calendar)
    try document.updateSettings(HydrationSettings(cupCapacityML: 180), at: date(), calendar: calendar)
    document.addCup(at: date().addingTimeInterval(0.2), calendar: calendar)
    try repository.save(document)
    var reloaded = try repository.load()
    let removed = reloaded.removeLastCup(on: date(), calendar: calendar)
    #expect(removed)
    #expect(reloaded.day(on: date(), calendar: calendar).totalML == 250)
}

@Test func localDateKeysAreCalendarAndTimeZoneAware() {
    let utc = LocalDay.calendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    let nearMidnight = date(hour: 0)
    #expect(LocalDay.key(for: nearMidnight, calendar: calendar) == "2026-10-15")
    #expect(LocalDay.key(for: nearMidnight, calendar: utc) == "2026-10-14")
    #expect(LocalDay.date(for: "2026-02-30", calendar: calendar) == nil)
    #expect(LocalDay.date(for: "garbage", calendar: calendar) == nil)
}

@Test func calendarWeeksAlwaysRunMondayThroughSunday() {
    let document = HydrationDocument()
    let week = document.week(containing: date(18), asOf: date(18), calendar: calendar)
    #expect(week.days.map(\.dayKey) == (12...18).map { "2026-10-\($0)" })
    #expect(week.elapsedDayCount == 7)
    #expect(week.days.allSatisfy { $0.cupCount == 0 })
    #expect(document.days.isEmpty)
    let monday = document.week(containing: date(19), asOf: date(19), calendar: calendar)
    #expect(monday.days.first?.dayKey == "2026-10-19")
    #expect(monday.days.last?.dayKey == "2026-10-25")
    #expect(monday.elapsedDayCount == 1)
}

@Test func weeklyAveragesIncludeZeroDaysButExcludeFutureDays() {
    var document = HydrationDocument(settings: HydrationSettings(dailyGoal: DailyGoal(value: 2)))
    document.addCup(at: date(12), calendar: calendar)
    document.addCup(at: date(14), calendar: calendar)
    document.addCup(at: date(14), calendar: calendar)
    // A future record must not affect an average as of Thursday.
    document.addCup(at: date(18), calendar: calendar)
    let current = document.week(containing: date(), asOf: date(), calendar: calendar)
    #expect(current.elapsedDayCount == 4)
    #expect(current.recordedDayCount == 2)
    #expect(current.goalReachedDayCount == 1)
    #expect(current.dailyAverage(in: .cups) == 0.75)
    #expect(current.dailyAverage(in: .milliliters) == 187.5)
    let completed = document.week(containing: date(), asOf: date(19), calendar: calendar)
    #expect(completed.elapsedDayCount == 7)
    #expect(completed.dailyAverage(in: .milliliters) == 1_000.0 / 7)
}

@Test func weeklyAverageUsesActualVolumesAfterCapacityChanges() throws {
    var document = HydrationDocument()
    document.addCup(at: date(12), calendar: calendar)
    try document.updateSettings(HydrationSettings(cupCapacityML: 180), at: date(13), calendar: calendar)
    document.addCup(at: date(13), calendar: calendar)
    let week = document.week(containing: date(13), asOf: date(13), calendar: calendar)
    #expect(week.dailyAverage(in: .cups) == 1)
    #expect(week.dailyAverage(in: .milliliters) == 215)
}

@Test func weekNavigationIncludesGapsAndStopsAtOldestNonemptyWeek() {
    var document = HydrationDocument()
    #expect(document.availableWeekCount(asOf: date(19), calendar: calendar) == 1)
    document.addCup(at: date(1), calendar: calendar)
    document.addCup(at: date(19), calendar: calendar)
    #expect(document.availableWeekCount(asOf: date(19), calendar: calendar) == 4)
    let gap = document.week(containing: date(6), asOf: date(19), calendar: calendar)
    #expect(gap.recordedDayCount == 0)
    #expect(gap.dailyAverage(in: .cups) == 0)
    document.removeLastCup(on: date(1), calendar: calendar)
    #expect(document.availableWeekCount(asOf: date(19), calendar: calendar) == 1)
}

@Test func weekNavigationIgnoresFutureRecordsAndEmptyDays() {
    var document = HydrationDocument()
    document.addCup(at: date(25), calendar: calendar)
    document.days.append(DayRecord(dayKey: "2020-01-01", settings: document.settings))
    #expect(document.availableWeekCount(asOf: date(19), calendar: calendar) == 1)
    let future = document.week(containing: date(25), asOf: date(15), calendar: calendar)
    #expect(future.elapsedDayCount == 0)
    #expect(future.dailyAverage(in: .cups) == 0)
}

@Test func weekRangesCrossYearsAndRespectInjectedTimeZones() {
    let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 12))!
    let week = HydrationDocument().week(containing: january, asOf: january, calendar: calendar)
    #expect(week.days.first?.dayKey == "2026-12-28")
    #expect(week.days.last?.dayKey == "2027-01-03")
    let utc = LocalDay.calendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    let mondayMidnight = date(19, hour: 0)
    #expect(LocalDay.key(for: LocalDay.startOfWeek(for: mondayMidnight, calendar: calendar), calendar: calendar) == "2026-10-19")
    #expect(LocalDay.key(for: LocalDay.startOfWeek(for: mondayMidnight, calendar: utc), calendar: utc) == "2026-10-12")
}

@Test func calendarWeekSpansDSTWithoutLosingADay() {
    let calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    let sunday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
    let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12))!
    var document = HydrationDocument()
    document.addCup(at: sunday, calendar: calendar)
    document.addCup(at: monday, calendar: calendar)
    let week = document.week(containing: sunday, asOf: monday, calendar: calendar)
    #expect(week.days.count == 7)
    #expect(Set(week.days.map(\.dayKey)).count == 7)
    #expect(week.days.first?.dayKey == "2026-03-02")
    #expect(week.days.last?.dayKey == "2026-03-08")
    #expect(document.availableWeekCount(asOf: monday, calendar: calendar) == 2)
}
