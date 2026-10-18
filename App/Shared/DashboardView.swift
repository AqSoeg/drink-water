import SwiftUI
import HydrationCore

struct DashboardView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showUndoConfirmation = false
    let showHistory: () -> Void

    var body: some View {
        ScrollView {
            WaterGlassGroup {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    totalCard
                    actions
                    todayEntries
                    weekCard
                }
            }
            .frame(maxWidth: 820)
            .padding(horizontalPadding)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("撤销今天最近一杯？", isPresented: $showUndoConfirmation, titleVisibility: .visible) {
            Button("撤销最近一杯", role: .destructive) { store.undoLastCup() }
            Button("取消", role: .cancel) {}
        }
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        30
        #else
        20
        #endif
    }

    private var header: some View {
        HStack {
            Text(WaterDate.full(store.now)).font(.headline)
            Spacer()
            Text(WaterDate.weekday(store.now))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("今日饮水", systemImage: "drop").font(.subheadline).foregroundStyle(.secondary)
            Button { store.toggleDisplayUnit() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.today.amount(in: store.settings.displayUnit))")
                        .font(.system(size: 76, weight: .medium, design: .rounded))
                        .monospacedDigit().contentTransition(.numericText())
                    Text(store.settings.displayUnit.title)
                        .font(.title2).foregroundStyle(.secondary)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canWrite)
            .accessibilityLabel("今天喝了\(store.settings.displayUnit.format(store.today.amount(in: store.settings.displayUnit)))")
            .accessibilityHint("切换杯数和毫升")
            .accessibilityIdentifier("totalAmountButton")
            GoalProgress(day: store.today, unit: store.settings.displayUnit)
        }
        .waterCard(padding: 26, tint: WaterTheme.accent.opacity(0.08))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.today.progress)
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Button { store.addCup() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                    Text("喝了一杯")
                    Text("\(store.settings.cupCapacityML) mL").font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(WaterPrimaryButton())
            .disabled(!store.canWrite)
            .accessibilityIdentifier("addCupButton")
            Button { showUndoConfirmation = true } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.medium))
                    .frame(width: 48, height: 48)
                    .waterGlass(cornerRadius: 18, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("撤销一杯")
            .disabled(store.today.cupCount == 0 || !store.canWrite)
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                SectionHeading(title: "每周饮水")
                Spacer()
                Text(store.settings.displayUnit.title)
                    .font(.caption).foregroundStyle(.secondary)
            }
            WeekChart(document: store.document, today: store.now, unit: store.settings.displayUnit)
        }
        .waterCard()
    }

    private var todayEntries: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading(title: "今日记录")
                Spacer()
                Button("查看历史", action: showHistory).buttonStyle(.plain)
                    .font(.caption.weight(.medium))
            }
            if store.today.drinks.isEmpty {
                EmptyWaterState(title: "暂无记录", symbol: "mug")
            } else {
                let entries = Array(store.today.drinks.reversed())
                ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    DrinkRow(entry: entry, ordinal: entries.count - index)
                    if index < min(entries.count, 5) - 1 { Divider().opacity(0.5) }
                }
                if entries.count > 5 {
                    Button("全部记录（\(entries.count)）", action: showHistory)
                        .buttonStyle(.plain).font(.caption)
                }
            }
        }
        .waterCard()
    }
}
