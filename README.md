# 饮水 · DrinkWater

一个使用 SwiftUI 编写的 iOS / macOS 饮水记录应用。数据仅保存在本机。

## 功能

- 一键记录、撤销今日最后一杯、查看和删除历史记录。
- 按杯数或毫升查看饮水量，设置每杯容量和每日目标，有效修改即时保存。
- 按周一至周日查看图表，支持触控滑动、Mac 触控板横向滚动和箭头翻周，最早可查看第一条记录所在周。
- 历史页展示所选周的记录天数、达标天数和日均饮水量。本周日均计算至今天，历史周按七天计算，空白日计为零。
- macOS 菜单栏快捷记录、独立主窗口和登录后自动启动。
- 支持深色模式、降低透明度、减少动态效果及旧系统材质回退。

## 开发

最低运行版本为 iOS 17 / macOS 14。Swift 包需要 Swift 6 工具链；应用使用部分系统 26 的玻璃 API，编译需 Xcode 26 或更新版本及相应 SDK。

打开 `DrinkWater.xcodeproj`，选择 `DrinkWaterIOS` 或 `DrinkWaterMac` scheme。真机运行需在 iOS target 的 Signing & Capabilities 中选择自己的开发团队，并在手机上开启开发者模式。

核心测试：

```sh
swift test
```

编译 macOS：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterMac \
  -destination 'platform=macOS' -derivedDataPath build/mac \
  CODE_SIGNING_ALLOWED=NO build
```

编译 iOS 模拟器：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios \
  CODE_SIGNING_ALLOWED=NO build
```

iOS UI 测试需选择实际模拟器 UDID：

```sh
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath build/ios -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

完整流程测试需要全新专用模拟器；周导航测试也可在专用模拟器预置多周本地测试数据后单独运行。不要使用真实手机数据作为测试夹具。

已安装应用且正在运行的专用模拟器命名为 `DrinkWater-Weekly...` 后，可使用以下命令验证跨周和空白周：

```sh
python3 scripts/seed_weekly_simulator.py <SIMULATOR_UDID>
xcodebuild -project DrinkWater.xcodeproj -scheme DrinkWaterIOS \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath build/ios -parallel-testing-enabled NO \
  -only-testing:DrinkWaterUITests/DrinkWaterUITests/testWeeklyHistoryNavigationAndUnits \
  CODE_SIGNING_ALLOWED=NO test
```

## 代码结构

- `Sources/HydrationCore`：数据模型、自然周统计和 JSON 持久化。
- `App/Shared`：共享界面与状态管理。
- `App/iOS`、`App/macOS`：平台入口及资源。
- `Configuration`：权限、隐私清单和 Info.plist。
- `Tests`：核心逻辑与 iOS UI 测试。

具体业务约束和协作说明见 [agent.md](agent.md)。
