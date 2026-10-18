import SwiftUI
import HydrationCore

@MainActor
@Observable
final class HydrationStore {
    private(set) var document = HydrationDocument()
    private(set) var now = Date()
    private(set) var canWrite = false
    var errorMessage: String?
    private let repository: HydrationRepository?

    var today: DayRecord { document.day(on: now) }
    var settings: HydrationSettings { document.settings }
    var history: [DayRecord] { document.days.sorted { $0.dayKey > $1.dayKey } }

    init() {
        do {
            repository = try HydrationRepository.applicationDefault()
        } catch {
            repository = nil
            errorMessage = "无法打开本地存储：\(error.localizedDescription)"
        }
        reload()
    }

    func reload() {
        refreshDate()
        guard let repository else { return }
        do {
            document = try repository.load()
            canWrite = true
            errorMessage = nil
        } catch {
            canWrite = false
            errorMessage = "无法读取饮水记录：\(error.localizedDescription)\n原始文件已保留，暂时停止记录，避免覆盖数据。"
        }
    }

    func refreshDate() { now = Date() }

    @discardableResult
    func addCup() -> Bool {
        refreshDate()
        return commit { $0.addCup(at: now) }
    }

    @discardableResult
    func undoLastCup() -> Bool {
        refreshDate()
        guard today.cupCount > 0 else { return false }
        return commit { $0.removeLastCup(on: now) }
    }

    @discardableResult
    func removeDrink(_ entry: DrinkEntry, from dayKey: String) -> Bool {
        commit { $0.removeDrink(id: entry.id, dayKey: dayKey) }
    }

    @discardableResult
    func saveSettings(_ settings: HydrationSettings) -> Bool {
        refreshDate()
        return commit { try $0.updateSettings(settings, at: now) }
    }

    func toggleDisplayUnit() {
        var updated = settings
        updated.displayUnit = updated.displayUnit == .cups ? .milliliters : .cups
        saveSettings(updated)
    }

    private func commit(_ change: (inout HydrationDocument) throws -> Void) -> Bool {
        guard canWrite, let repository else {
            errorMessage = "本地记录尚未成功加载，无法保存。请重试读取，原始数据不会被覆盖。"
            return false
        }
        do {
            var updated = document
            try change(&updated)
            // Publish only after the atomic disk write succeeds, so the UI never claims an unsaved drink.
            try repository.save(updated)
            document = updated
            return true
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)\n本次修改未生效，请重试。"
            return false
        }
    }
}
