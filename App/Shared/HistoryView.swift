import SwiftUI
import HydrationCore

struct HistoryView: View {
    @Environment(HydrationStore.self) private var store
    @State private var selectedDayKey: String?
    @State private var unit: WaterUnit = .cups
    @State private var pendingDelete: DrinkEntry?

    var body: some View {
        ScrollView {
            WaterGlassGroup {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        SectionHeading(title: "历史记录")
                            .fixedSize(horizontal: true, vertical: false)
                        WaterUnitPicker(title: "显示单位", selection: $unit, showsTitle: false)
                    }
                    overview
                    if store.history.isEmpty {
                        EmptyWaterState(title: "暂无记录", symbol: "clock.arrow.circlepath")
                            .waterCard()
                    } else {
                        dayList
                    }
                }
            }
            .frame(maxWidth: 820).padding(24).frame(maxWidth: .infinity)
        }
        .onAppear {
            unit = store.settings.displayUnit
            if selectedDayKey == nil { selectedDayKey = store.history.first?.dayKey }
        }
        .confirmationDialog("删除这杯记录？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("删除这杯记录", role: .destructive) {
                if let entry = pendingDelete, let selectedDayKey {
                    store.removeDrink(entry, from: selectedDayKey)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            if let entry = pendingDelete {
                Text("\(WaterDate.time(entry.timestamp)) · \(entry.volumeML) mL")
            }
        }
    }

    private var overview: some View {
        WeekChart(document: store.document, today: store.now, unit: unit, showsStatistics: true)
            .waterCard()
    }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(title: "每日记录")
            LazyVStack(spacing: 9) {
                ForEach(store.history) { day in
                    Button {
                        selectedDayKey = selectedDayKey == day.dayKey ? nil : day.dayKey
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(day.dayKey == store.today.dayKey ? "今天" : dayTitle(day))
                                    .font(.subheadline.weight(.medium))
                                Text(day.isGoalReached ? "已达目标" : "目标 \(day.goalCurrentValue)/\(day.goal.value)\(day.goal.unit.title)")
                                    .font(.caption).foregroundStyle(day.isGoalReached ? WaterTheme.accent : .secondary)
                            }
                            Spacer()
                            Text(unit.format(day.amount(in: unit)))
                                .font(.headline).monospacedDigit()
                            Image(systemName: selectedDayKey == day.dayKey ? "chevron.down" : "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(selectedDayKey == day.dayKey ? WaterTheme.accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 15))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dayTitle(day))，\(unit.format(day.amount(in: unit)))，\(selectedDayKey == day.dayKey ? "收起详情" : "查看详情")")
                    if selectedDayKey == day.dayKey {
                        detail(day)
                    }
                }
            }
        }
        .waterCard()
    }

    private func dayTitle(_ day: DayRecord) -> String {
        LocalDay.date(for: day.dayKey).map(WaterDate.full) ?? day.dayKey
    }

    private func detail(_ day: DayRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(day.cupCount) 杯 · 合计 \(day.totalML) mL")
                .font(.subheadline).foregroundStyle(.secondary)
            if day.drinks.isEmpty {
                Text("暂无记录")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
            } else {
                ForEach(Array(day.drinks.reversed())) { entry in
                    HStack(spacing: 12) {
                        DrinkRow(entry: entry)
                        Button { pendingDelete = entry } label: {
                            Image(systemName: "trash").foregroundStyle(.secondary).padding(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.canWrite)
                        .accessibilityLabel("删除 \(WaterDate.time(entry.timestamp)) 这杯记录")
                    }
                    Divider().opacity(0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
