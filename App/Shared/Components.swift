import SwiftUI
import Charts
import HydrationCore

struct SectionHeading: View {
    let title: String

    var body: some View {
        Text(title).font(.headline)
    }
}

struct WaterUnitPicker: View {
    let title: String
    @Binding var selection: WaterUnit
    var usesGoalLabels = false
    var showsTitle = true

    var body: some View {
        HStack(spacing: 16) {
            if showsTitle {
                Text(title)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
            Picker(title, selection: $selection) {
                ForEach(WaterUnit.allCases) { unit in
                    Text(usesGoalLabels ? (unit == .cups ? "按杯数" : "按毫升") : unit.title)
                        .tag(unit)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: usesGoalLabels ? 180 : 110)
            .accessibilityIdentifier(usesGoalLabels ? "goalUnitPicker" : "displayUnitPicker")
        }
        .frame(maxWidth: .infinity)
    }
}

struct GoalProgress: View {
    let day: DayRecord
    let unit: WaterUnit

    private var target: String {
        day.goalAmount(in: unit).formatted(
            .number.locale(Locale(identifier: "zh_CN")).grouping(.never).precision(.fractionLength(0...2))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "今天饮水目标 \(day.amount(in: unit))/\(target)\(unit.title)")
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("goalProgressLabel")
            ProgressView(value: min(day.progress, 1))
                .tint(WaterTheme.accent)
                .accessibilityLabel("每日饮水目标")
                .accessibilityValue("已完成百分之\(Int((day.progress * 100).rounded()))")
        }
    }
}

struct WeekChart: View {
    let document: HydrationDocument
    let today: Date
    let unit: WaterUnit
    var showsStatistics = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedWeekOffset: Int? = 0

    private var weekCount: Int { document.availableWeekCount(asOf: today) }
    private var offset: Int { min(max(selectedWeekOffset ?? 0, 0), weekCount - 1) }
    private var selectedWeek: HydrationWeek { week(at: offset) }

    private func week(at offset: Int) -> HydrationWeek {
        let calendar = LocalDay.calendar()
        let start = LocalDay.startOfWeek(for: today, calendar: calendar)
        let date = calendar.date(byAdding: .day, value: -offset * 7, to: start) ?? start
        return document.week(containing: date, asOf: today, calendar: calendar)
    }

    private var dateRange: String {
        guard let first = selectedWeek.days.first, let last = selectedWeek.days.last,
              let start = LocalDay.date(for: first.dayKey), let end = LocalDay.date(for: last.dayKey) else { return "" }
        let format = Date.FormatStyle.dateTime.locale(Locale(identifier: "zh_CN"))
        let startText = start.formatted(format.year().month().day())
        let endText = end.formatted(format.month().day())
        return "\(startText) – \(endText)"
    }

    private var averageText: String {
        selectedWeek.dailyAverage(in: unit).formatted(
            .number.locale(Locale(identifier: "zh_CN")).grouping(.never)
                .precision(.fractionLength(unit == .cups ? 0...1 : 0...0))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Text(offset == 0 ? "本周 · \(dateRange)" : dateRange)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("weekRangeLabel")
                Spacer(minLength: 0)
                Button { selectWeek(offset + 1) } label: {
                    Image(systemName: "chevron.left").frame(width: 30, height: 30)
                }
                .disabled(offset >= weekCount - 1)
                .accessibilityLabel("上一周")
                .accessibilityIdentifier("previousWeekButton")
                Button { selectWeek(offset - 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 30, height: 30)
                }
                .disabled(offset == 0)
                .accessibilityLabel("下一周")
                .accessibilityIdentifier("nextWeekButton")
            }
            .buttonStyle(.plain)

            if showsStatistics {
                HStack(spacing: 12) {
                    statistic("有记录", value: "\(selectedWeek.recordedDayCount)", suffix: "天")
                    Divider().frame(height: 38)
                    statistic("达标", value: "\(selectedWeek.goalReachedDayCount)", suffix: "天")
                    Divider().frame(height: 38)
                    statistic("日均", value: averageText, suffix: unit.title)
                        .accessibilityIdentifier("weeklyAverageStatistic")
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach((0..<weekCount).reversed(), id: \.self) { pageOffset in
                        chart(for: week(at: pageOffset))
                            .containerRelativeFrame(.horizontal)
                            .id(pageOffset)
                            .accessibilityHidden(pageOffset != offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .defaultScrollAnchor(.trailing)
            .scrollPosition(id: $selectedWeekOffset, anchor: .center)
            .frame(height: 170)
            .accessibilityIdentifier("weeklyChartPager")
        }
        .onChange(of: weekCount) { _, count in
            if let selectedWeekOffset, selectedWeekOffset >= count { self.selectedWeekOffset = count - 1 }
        }
        .onChange(of: LocalDay.key(for: LocalDay.startOfWeek(for: today))) { _, _ in
            selectedWeekOffset = 0
        }
    }

    private func selectWeek(_ offset: Int) {
        guard (0..<weekCount).contains(offset) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            selectedWeekOffset = offset
        }
    }

    private func statistic(_ title: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                Text(suffix).font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value) \(suffix)")
    }

    private func chart(for week: HydrationWeek) -> some View {
        Chart(week.days) { day in
            BarMark(x: .value("日期", day.dayKey), y: .value("饮水量", day.amount(in: unit)), width: .ratio(0.48))
                .foregroundStyle(day.dayKey == LocalDay.key(for: today) ? WaterTheme.accent : WaterTheme.accent.opacity(0.55))
                .cornerRadius(5)
                .accessibilityLabel(day.dayKey)
                .accessibilityValue(unit.format(day.amount(in: unit)))
        }
        .chartXScale(domain: week.days.map(\.dayKey))
        .chartYScale(domain: 0...max(week.days.map { $0.amount(in: unit) }.max() ?? 0, unit == .cups ? 8 : 2_000))
        .chartXAxis {
            AxisMarks(values: week.days.map(\.dayKey)) { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let date = LocalDay.date(for: key) {
                        let weekday = LocalDay.calendar().component(.weekday, from: date)
                        Text(["日", "一", "二", "三", "四", "五", "六"][weekday - 1]).font(.caption)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.primary.opacity(0.06))
                AxisValueLabel().font(.caption2)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
        .accessibilityLabel("每周饮水量，单位\(unit.title)")
    }
}

struct DrinkRow: View {
    let entry: DrinkEntry
    var ordinal: Int? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mug")
                .font(.system(size: 18))
                .foregroundStyle(WaterTheme.accent)
                .frame(width: 42, height: 42)
                .background(WaterTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(ordinal.map { "第 \($0) 杯" } ?? "一杯水").font(.subheadline.weight(.medium))
                Text(WaterDate.time(entry.timestamp)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            Text("\(entry.volumeML) mL").font(.subheadline.weight(.medium)).monospacedDigit()
        }
        .padding(.vertical, 5)
    }
}

struct EmptyWaterState: View {
    let title: String
    var symbol = "drop"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(WaterTheme.accent)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 25)
    }
}
