# DrinkWater 项目协作指南

本文依据当前源码、Xcode 工程和测试整理，供后续在此目录工作的开发者与 Agent 使用。结构或行为发生变化时同步更新本文。

## 项目概况

- 产品名称为「饮水」，是使用 SwiftUI 编写的 macOS / iOS 本地饮水记录应用。
- 已有功能：记录一杯水、撤销今日最后一杯、删除指定历史记录、杯数 / 毫升显示切换、每日目标、自然周图表与翻周、每周日均统计、历史记录、即时保存设置，以及 macOS 登录启动。
- 默认每杯 250 mL，每日目标 8 杯，默认显示杯数。
- 最低运行版本为 macOS 14、iOS 17。玻璃效果使用 macOS / iOS 26 API，并提供旧系统回退；编译应用需要包含这些 API 的 SDK。
- 核心库采用 Swift Package Manager，`swift-tools-version` 为 6.0；Xcode 应用和 UI 测试目前使用 Swift 5 语言模式。修改并发代码时区分这些设置。
- 没有第三方包依赖；当前没有网络服务、账号、云同步或饮水提醒实现。

## 目录与职责

| 路径 | 职责 |
| --- | --- |
| `Package.swift` | 定义 `HydrationCore` 库与 `HydrationCoreTests`，不包含应用或 UI 测试 target |
| `Sources/HydrationCore/HydrationModels.swift` | 设置、目标、饮水记录、自然日、统计与数据校验 |
| `Sources/HydrationCore/HydrationWeek.swift` | 周一至周日的自然周、可浏览周数、按周统计与日均计算 |
| `Sources/HydrationCore/HydrationRepository.swift` | JSON 读取、验证和原子写入 |
| `App/Shared/HydrationStore.swift` | `@MainActor @Observable` 应用状态与保存事务 |
| `App/Shared/RootView.swift` | macOS 侧栏 / iOS Tab 导航、日期刷新、读取恢复入口 |
| `App/Shared/DashboardView.swift` | 今日总量、记录与撤销、今日明细、七天图表 |
| `App/Shared/HistoryView.swift` | 历史汇总、按日展开、单条记录删除 |
| `App/Shared/SettingsView.swift` | `HydrationSettingsDraft`、设置校验与即时持久化、macOS 登录启动 |
| `App/Shared/Theme.swift` | 配色、日期格式、玻璃卡片和按钮、无障碍及旧系统回退 |
| `App/Shared/Components.swift` | 单位选择器、目标进度、图表和记录行等共享组件 |
| `App/macOS/DrinkWaterMacApp.swift` | 菜单栏入口、AppKit 窗口生命周期、独立日期计时器 |
| `App/iOS/DrinkWaterIOSApp.swift` | iOS 应用入口与 Store 注入 |
| `App/iOS/Assets.xcassets/AppIcon.appiconset/` | iOS 主屏幕图标，使用 1024×1024 不透明 PNG；两个 iOS 构建配置通过 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 引用 |
| `Configuration/` | 两端 Info.plist、macOS 沙盒权限和隐私清单 |
| `DrinkWater.xcodeproj/` | 两端应用 target、iOS UI 测试 target、共享 schemes、对根目录 Swift 包的引用 |
| `Tests/HydrationCoreTests/` | Swift Testing 核心逻辑和持久化测试 |
| `Tests/DrinkWaterUITests/` | XCTest iOS 完整流程与单位切换布局测试 |

`.build/`、`.swiftpm/`、`build/`、`DerivedData/` 和 Xcode 用户状态属于生成物或本机状态，不作为源码修改。搜索时排除它们。GitHub 仓库为 `https://github.com/AqSoeg/drink-water`；执行 Git 工作流前先检查实际状态。

## 架构与修改约定

- 业务规则放在 `HydrationCore`，保持仅依赖 Foundation；UI、平台服务和交互状态留在 `App/`。
- View 通过环境获取 `HydrationStore`，业务写入走 Store 的方法，避免从 View 直接写文件。
- Store 的 `commit` 先复制文档、执行修改、完成原子保存，成功后才发布 `document`。保存失败时界面不能把该修改显示为已成功。
- 共享 UI 应兼容两端，平台专属代码使用 `#if os(macOS)` / `#if os(iOS)` 隔离。优先复用现有主题和组件，沿用四空格缩进、类型大驼峰、成员小驼峰和中文界面文案。
- 新增 `App/Shared` 文件时，要同时维护 Xcode 工程中两个应用 target 的文件引用与 Sources 列表；当前工程没有自动同步文件夹。新增 UI 测试文件同样需要加入测试 target。核心库文件由 SwiftPM 按目录发现。
- 修改 Bundle ID、签名、沙盒、隐私清单和最低系统版本时，说明具体需求，不顺带调整。

## 必须保留的业务规则

1. **原始饮水量不可追溯改写。** 每次添加记录保存当时的 `volumeML`；之后更改杯容量只影响新记录。例如先记录 250 mL，再改为 180 mL 并添加一杯，应得到 2 杯、430 mL。
2. **杯数等于记录条数。** 不能用总毫升除以当前杯容量计算杯数。杯数目标按条数判断，毫升目标按实际体积总和判断。
3. **目标保存每日快照。** `DayRecord` 保存 `goal` 和 `goalCupCapacityML`；修改设置更新今天已有记录的目标，历史目标及其容量快照保持不变。
4. **显示切换与目标转换各有语义。** 切换显示单位只改变展示偏好，不改写目标单位。设置页切换目标单位时使用 `DailyGoal.converted`，按已保存杯容量换算，毫升转整数杯数向上取整；输入或结果越界时拒绝修改。目标展示可保留小数杯数，例如 900 mL / 250 mL 显示为 3.6 杯。
5. **按本地自然日归档。** 使用 `LocalDay` 和 Calendar 生成 `yyyy-MM-dd`，不要截取 UTC 时间字符串或使用固定 24 小时偏移计算前一天。跨日时刷新日期，保留历史；测试显式注入 Calendar / 时区。
6. **撤销按追加顺序。** 只移除今天数组中的最后一条记录，不使用最大时间戳；相同时间戳和系统时钟回拨后仍需正确。
7. **周图表按自然周分页。** 每页固定周一至周日，横轴只显示「一、二、三、四、五、六、日」。空白日补零，查询不写入持久化记录；中间的空白周仍可浏览，最早边界为第一条非空记录所在周，最新边界为本周。`recentDays` 保留原有滚动日期查询语义，UI 周图表使用 `week(containing:asOf:calendar:)`。
8. **超额记录照常保留。** 数据层进度允许大于 1，仅进度条在展示时截到 1，不能截断实际杯数或毫升量。
9. **周统计和分页同步。** 「有记录、达标、日均」均针对选中周。本周日均分母为周一至今天的自然日数，历史周为七天，未记录的日期计零；未来日期不参与统计。杯数日均按记录条数计算，毫升日均按记录原始体积计算。使用 Calendar 日期运算，不能按固定秒数计算周数。

## 数据与错误处理

- 默认存储位置由 `FileManager` 的用户级 Application Support 目录决定，再追加 `DrinkWater/hydration.json`。macOS 开启 App Sandbox，实际位置可能在应用容器内；不要硬编码用户绝对路径。
- 数据为 `HydrationDocument`，当前 `version == 1`。日期使用 ISO 8601 编解码，输出 JSON 使用排序键和易读格式，写入使用 `.atomic`。
- 只有文件不存在才视为首次使用。文件损坏、无法读取、校验失败或版本不支持时必须保留原文件，并通过 `canWrite == false` 暂停写入，提供重试读取入口。不得用空文档覆盖异常文件。
- 校验范围：杯容量和单条记录体积为 10–2000 mL，杯数目标为 1–100，毫升目标为 50–20000；日期键必须有效且唯一，记录 UUID 全局唯一，时间戳必须有限。
- 变更持久化格式时同时考虑版本兼容、校验和迁移，并补充往返读写与异常数据测试。
- 测试持久化应使用临时目录，避免触碰真实饮水数据。

## 设置和 UI 注意事项

- 设置采用有效输入即时保存，无需保存按钮。未完成或无效数字输入保留在草稿中，不应阻止其他独立设置修改，也不能覆盖这些修改。
- `HydrationSettingsDraft` 在根视图持有；同步时保留未完成输入，避免切换页面或外部设置变化导致二次换算、丢失草稿。
- 今日总量切换单位时保持卡片和下方控件位置稳定；「今日记录」在「每周饮水」上方。
- 仅「历史记录」页的显示单位选择器隐藏可见标题并保留无障碍名称；「偏好设置」必须保留「显示单位」标题，每日目标单位选择器也保留标题。周图表使用共享 `WeekChart`、原生横向 ScrollView 分页和翻周按钮，兼容两端及减少动态效果设置。
- 保留 `totalAmountButton`、`addCupButton`、`goalProgressLabel`、`cupCapacityField`、`dailyGoalField` 等测试依赖的 accessibility identifier。修改交互或文案时同步检查 UI 测试。
- 继续支持深色模式、减少动态效果、降低透明度和旧系统材质回退。
- macOS 使用 `MenuBarExtra`，`LSUIElement` 为 true。关闭主窗口后应用继续运行；再次打开应用或点击菜单入口应显示已有主窗口。
- macOS 菜单栏标签保持结构稳定。代码已记录在标签中使用 `TimelineView` 会在 macOS 27 启动时触发更新循环，日期刷新应继续放在外部计时器或生命周期事件中。

## 构建与验证

以下命令在项目根目录运行。应用构建需要完整 Xcode 与对应 SDK；真机运行还需要有效签名配置。文档中的命令根据当前配置整理，不代表本次已执行通过。

核心库测试（不编译 SwiftUI 应用）：

```sh
swift test
```

macOS 本地编译检查：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterMac \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

iOS 模拟器编译检查：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

运行 iOS UI 测试前先确认可用目的地：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS -showdestinations
```

将实际测试模拟器的 UDID 填入以下命令：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath build/DerivedData \
  -only-testing:DrinkWaterUITests test
```

- 完整流程测试 `testCompleteHydrationWorkflow` 要求全新模拟器中的首次启动数据，并会写入记录和设置；重跑使用新的专用测试模拟器，不通过生产代码增加清空数据入口。
- UI 测试涵盖记录、显示单位、即时保存与目标换算、历史体积、撤销、冷启动持久化、单位切换前后的布局位置，以及周图表手势 / 按钮翻页、边界和统计单位切换；失败时保留截图和 accessibility tree 附件。
- 核心测试涵盖杯容量变更、目标转换、历史目标、跨日和时区、撤销追加顺序、指定删除、七天统计、越界校验、JSON 往返及损坏文件保护。
- 核心规则或存储变更运行 `swift test`；共享 UI 变更编译两端并检查相关 UI 流程；macOS 生命周期变更还需检查首次启动、菜单栏、关闭窗口后重新打开和跨日刷新。
- `DrinkWaterMac` scheme 的 Testables 当前为空，不能用它替代核心库测试。
- 纯文档修改无需构建应用。交付时说明修改内容、实际验证结果和未执行的检查；不要把已有构建产物当作当前验证通过的证据。
