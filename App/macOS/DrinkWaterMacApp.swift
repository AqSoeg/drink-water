import SwiftUI
import AppKit
import HydrationCore

@main
struct DrinkWaterMacApp: App {
    @NSApplicationDelegateAdaptor(DrinkWaterMacDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(openDashboard: appDelegate.showDashboard)
                .environment(appDelegate.store)
        } label: {
            // Keep this label static in structure. TimelineView here can cause an
            // endless MenuBarExtra update loop during launch on macOS 27.
            Label("\(appDelegate.store.today.cupCount) 杯", systemImage: "drop.fill")
                .accessibilityLabel("饮水，今天 \(appDelegate.store.today.cupCount) 杯")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("饮水") {
                Button("打开主界面", action: appDelegate.showDashboard)
                    .keyboardShortcut("0", modifiers: .command)
                Button("喝了一杯") { appDelegate.store.addCup() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .disabled(!appDelegate.store.canWrite)
            }
        }
    }
}

@MainActor
final class DrinkWaterMacDelegate: NSObject, NSApplicationDelegate {
    let store = HydrationStore()
    private var dashboardWindow: NSWindow?
    private var dateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Update the date outside the menu bar's label/rendering lifecycle.
        dateTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.store.refreshDate() }
        }
        if let dateTimer { RunLoop.main.add(dateTimer, forMode: .common) }
        // Wait until SwiftUI has finished constructing its menu bar scene.
        DispatchQueue.main.async { [weak self] in self?.showDashboard() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Finder's second double-click sends a reopen event, not a fresh launch.
        showDashboard()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        dateTimer?.invalidate()
    }

    func showDashboard() {
        store.refreshDate()
        let window: NSWindow
        if let dashboardWindow {
            window = dashboardWindow
        } else {
            let controller = NSHostingController(rootView: RootView().environment(store))
            window = NSWindow(contentViewController: controller)
            window.title = "饮水"
            window.identifier = NSUserInterfaceItemIdentifier("dashboard")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 780, height: 640)
            window.setContentSize(NSSize(width: 960, height: 820))
            window.center()
            window.setFrameAutosaveName("DrinkWaterDashboard")
            dashboardWindow = window
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuPanel: View {
    @Environment(HydrationStore.self) private var store
    let openDashboard: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("饮水", systemImage: "drop.fill").font(.headline).foregroundStyle(WaterTheme.accent)
                Spacer()
                Text(WaterDate.short(store.now)).font(.caption).foregroundStyle(.secondary)
            }
            Button { store.toggleDisplayUnit() } label: {
                Text(store.settings.displayUnit.format(store.today.amount(in: store.settings.displayUnit)))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
            }
            .buttonStyle(.plain).disabled(!store.canWrite)
            GoalProgress(day: store.today, unit: store.settings.displayUnit)
            Button { store.addCup() } label: {
                Label("喝了一杯 · \(store.settings.cupCapacityML) mL", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WaterPrimaryButton()).disabled(!store.canWrite)
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if !store.canWrite {
                Button("重试读取") { store.reload() }
            }
            Divider()
            HStack {
                Button(action: openDashboard) {
                    Label("打开主界面", systemImage: "square.grid.2x2").font(.subheadline)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("退出饮水")
            }
        }
        .padding(22).frame(width: 310)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .tint(WaterTheme.accent)
        .onAppear { store.refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            store.refreshDate()
        }
    }
}
