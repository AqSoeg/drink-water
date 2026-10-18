import SwiftUI
import Observation
import HydrationCore
#if os(macOS)
import ServiceManagement
#endif

@MainActor
@Observable
final class HydrationSettingsDraft {
    var capacity = "250"
    var goalValue = "8"
    var goalUnit: WaterUnit = .cups
    var displayUnit: WaterUnit = .cups
    private(set) var loaded = false
    private(set) var goalUnitMessage: String?
    private var baseline: HydrationSettings?

    var isCapacityValid: Bool {
        guard let value = Int(capacity) else { return false }
        return (10...2_000).contains(value)
    }

    var isGoalValid: Bool {
        guard let value = Int(goalValue) else { return false }
        return DailyGoal(value: value, unit: goalUnit).isValid
    }

    func synchronize(with settings: HydrationSettings) {
        guard loaded, let baseline else {
            capacity = String(settings.cupCapacityML)
            goalValue = String(settings.dailyGoal.value)
            goalUnit = settings.dailyGoal.unit
            displayUnit = settings.displayUnit
            self.baseline = settings
            loaded = true
            return
        }
        guard baseline != settings else { return }
        let capacityChanged = capacity != String(baseline.cupCapacityML)
        let goalChanged = goalValue != String(baseline.dailyGoal.value) || goalUnit != baseline.dailyGoal.unit
        let displayChanged = displayUnit != baseline.displayUnit
        if !capacityChanged { capacity = String(settings.cupCapacityML) }
        if !goalChanged {
            goalValue = String(settings.dailyGoal.value)
            goalUnit = settings.dailyGoal.unit
        }
        if !displayChanged { displayUnit = settings.displayUnit }
        self.baseline = settings
    }

    func setCapacity(_ text: String, in store: HydrationStore) {
        capacity = text
        guard isCapacityValid, let value = Int(text) else { return }
        var settings = store.settings
        settings.cupCapacityML = value
        persist(settings, in: store)
    }

    func setGoalValue(_ text: String, in store: HydrationStore) {
        goalUnitMessage = nil
        goalValue = text
        guard isGoalValid, let value = Int(text) else { return }
        var settings = store.settings
        settings.dailyGoal = DailyGoal(value: value, unit: goalUnit)
        persist(settings, in: store)
    }

    func setGoalUnit(_ unit: WaterUnit, in store: HydrationStore) {
        guard goalUnit != unit else { return }
        // Change the value and unit together, with a single atomic write. Never
        // reinterpret an invalid input or silently truncate an out-of-range goal.
        guard isGoalValid, let value = Int(goalValue) else {
            goalUnitMessage = "请先输入有效目标"
            return
        }
        guard let goal = DailyGoal(value: value, unit: goalUnit).converted(
            to: unit, cupCapacity: store.settings.cupCapacityML
        ) else {
            goalUnitMessage = "换算结果超出范围，原目标未更改"
            return
        }
        goalUnit = goal.unit
        setGoalValue(String(goal.value), in: store)
    }

    func setDisplayUnit(_ unit: WaterUnit, in store: HydrationStore) {
        displayUnit = unit
        var settings = store.settings
        settings.displayUnit = unit
        persist(settings, in: store)
    }

    private func persist(_ settings: HydrationSettings, in store: HydrationStore) {
        // Each control updates only its own setting, so an incomplete numeric
        // input cannot block or overwrite an unrelated change.
        guard settings != store.settings, store.canWrite else { return }
        if store.saveSettings(settings) { synchronize(with: store.settings) }
    }
}

@MainActor
struct SettingsView: View {
    @Environment(HydrationStore.self) private var store
    @Bindable var editor: HydrationSettingsDraft
    #if os(macOS)
    @State private var launchAtLogin = false
    @State private var loginMessage: String?
    #endif

    var body: some View {
        ScrollView {
            WaterGlassGroup {
                VStack(alignment: .leading, spacing: 24) {
                    capacityCard
                    goalCard
                    displayCard
                    #if os(macOS)
                    loginCard
                    #endif
                }
            }
            .frame(maxWidth: 680).padding(24).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            editor.synchronize(with: store.settings)
            #if os(macOS)
            launchAtLogin = SMAppService.mainApp.status == .enabled
            #endif
        }
        .onChange(of: store.settings) { _, settings in editor.synchronize(with: settings) }
    }

    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            numberField(title: "每杯容量", text: Binding(
                get: { editor.capacity },
                set: { editor.setCapacity($0, in: store) }
            ), suffix: "mL")
            HStack(spacing: 8) {
                ForEach([180, 250, 350, 500], id: \.self) { value in
                    Button { editor.setCapacity(String(value), in: store) } label: {
                        Text("\(value)")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(editor.capacity == String(value) ? WaterTheme.accent : .secondary)
                            .background(editor.capacity == String(value) ? WaterTheme.accent.opacity(0.16) : .primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.canWrite)
                    .accessibilityLabel("杯容量 \(value) 毫升")
                }
            }
            if !editor.isCapacityValid {
                Text("容量须为 10–2000 mL 的整数")
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .waterCard()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("每日目标", systemImage: "scope").font(.headline)
            WaterUnitPicker(title: "目标单位", selection: Binding(
                get: { editor.goalUnit },
                set: { editor.setGoalUnit($0, in: store) }
            ), usesGoalLabels: true)
            .disabled(!store.canWrite)
            numberField(title: "目标", text: Binding(
                get: { editor.goalValue },
                set: { editor.setGoalValue($0, in: store) }
            ), suffix: editor.goalUnit.title)
            if !editor.isGoalValid {
                Text(editor.goalUnit == .cups ? "目标须为 1–100 杯的整数" : "目标须为 50–20000 mL 的整数")
                    .font(.caption).foregroundStyle(.red)
            } else if let message = editor.goalUnitMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
        .waterCard()
    }

    private var displayCard: some View {
        WaterUnitPicker(title: "显示单位", selection: Binding(
            get: { editor.displayUnit },
            set: { editor.setDisplayUnit($0, in: store) }
        ))
        .disabled(!store.canWrite)
        .waterCard()
    }

    private func numberField(title: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(.title2, design: .rounded, weight: .medium))
                .frame(width: 104)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .disabled(!store.canWrite)
                .accessibilityLabel(title)
                .accessibilityIdentifier(title == "每杯容量" ? "cupCapacityField" : "dailyGoalField")
            Text(suffix).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
    }

    #if os(macOS)
    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("登录后自动启动", isOn: Binding(get: { launchAtLogin }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        loginMessage = SMAppService.mainApp.status == .requiresApproval
                            ? "请在系统设置 → 通用 → 登录项中允许此应用。" : nil
                    } catch {
                        loginMessage = "无法更改自动启动：\(error.localizedDescription)"
                    }
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }))
                .font(.headline)
            if let loginMessage {
                Text(loginMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .waterCard()
    }
    #endif
}
