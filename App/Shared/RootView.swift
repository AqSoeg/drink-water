import SwiftUI
import Combine

enum WaterPage: String, CaseIterable, Identifiable {
    case dashboard, history, settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "今日"
        case .history: "历史记录"
        case .settings: "偏好设置"
        }
    }
    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
struct RootView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: WaterPage = .dashboard
    @State private var settingsEditor = HydrationSettingsDraft()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            #if os(macOS)
            HStack(spacing: 0) {
                sidebar
                pageContent(page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 780, minHeight: 640)
            #else
            TabView(selection: $page) {
                ForEach(WaterPage.allCases) { destination in
                    NavigationStack {
                        pageContent(destination)
                            .background { WaterBackdrop() }
                            .navigationTitle(destination == .dashboard ? "饮水" : destination.title)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .tabItem { Label(destination.title, systemImage: destination.symbol) }
                    .tag(destination)
                }
            }
            #endif
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.canWrite { recoveryBanner }
        }
        .tint(WaterTheme.accent)
        .background { WaterBackdrop() }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onAppear { store.refreshDate() }
        .onReceive(clock) { _ in store.refreshDate() }
        .onChange(of: store.settings) { _, settings in
            if settingsEditor.loaded { settingsEditor.synchronize(with: settings) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDate() }
        }
        .alert("本地记录", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            if !store.canWrite {
                Button("重试读取") { store.reload() }
            }
            Button("知道了", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func pageContent(_ destination: WaterPage) -> some View {
        switch destination {
        case .dashboard: DashboardView { page = .history }
        case .history: HistoryView()
        case .settings: SettingsView(editor: settingsEditor)
        }
    }

    private var recoveryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield").foregroundStyle(.orange)
            Text("记录读取失败，已暂停写入").font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Button("重试读取") { store.reload() }.buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WaterTheme.surface)
    }

    #if os(macOS)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 22)).foregroundStyle(WaterTheme.accent)
                    .frame(width: 36, height: 36)
                Text("饮水").font(.title2.weight(.semibold))
            }
            .padding(.top, 12)
            VStack(spacing: 7) {
                ForEach(WaterPage.allCases) { destination in
                    Button { page = destination } label: {
                        HStack(spacing: 12) {
                            Image(systemName: destination.symbol).frame(width: 19)
                            Text(destination.title).font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(page == destination ? WaterTheme.accent : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(page == destination ? WaterTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 13))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar-\(destination.rawValue)")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 188)
        .waterGlass(cornerRadius: 24)
        .padding(.leading, 16)
        .padding(.vertical, 16)
    }
    #endif
}
