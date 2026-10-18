import XCTest

@MainActor
final class DrinkWaterUITests: XCTestCase {
    private let app = XCUIApplication()
    private let timeout: TimeInterval = 10

    private enum WorkflowError: Error {
        case assertionFailed
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false {
            screenshot("Failure")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Failure-AccessibilityTree"
            tree.lifetime = .keepAlways
            add(tree)
        }
    }

    // Run once on a newly created simulator: no launch arguments or production reset hook.
    func testCompleteHydrationWorkflow() throws {
        app.launch()

        try XCTContext.runActivity(named: "Dashboard: fresh launch and three 250 mL cups") { _ in
            try assertTotal("0 杯")
            screenshot("Dashboard-Initial-0-Cups")
            for count in 1...3 {
                try tap(app.buttons["addCupButton"])
                try assertTotal("\(count) 杯")
            }
            screenshot("Dashboard-3-Cups")
            try assertGoal("今天饮水目标 3/8杯")
            try tap(totalAmountButton)
            try assertTotal("750 mL")
            try assertGoal("今天饮水目标 750/2000mL")
            screenshot("Dashboard-750-mL")
            try tap(totalAmountButton)
            try assertTotal("3 杯")
        }

        try XCTContext.runActivity(named: "Settings: immediately persist capacity and atomic goal unit conversion") { _ in
            try selectTab("偏好设置")
            let capacity = app.textFields["cupCapacityField"]
            try reveal(capacity)
            try wait(NSPredicate(format: "value == %@", "250"), on: capacity,
                     message: "Fresh settings should have a 250 mL capacity")
            screenshot("Settings-Initial-250-mL")
            XCTAssertFalse(app.buttons["saveSettingsButton"].exists)
            try tap(app.buttons["杯容量 180 毫升"])
            try selectTab("今日")
            try wait(NSPredicate(format: "label CONTAINS %@", "180"), on: app.buttons["addCupButton"],
                     message: "Capacity must be effective immediately without a save button")
            try selectTab("偏好设置")
            try wait(NSPredicate(format: "value == %@", "180"), on: capacity,
                     message: "Capacity text field should contain 180")
            screenshot("Settings-Edited-180-mL")
            let goal = app.textFields["dailyGoalField"]
            try tap(app.buttons["按毫升"])
            try reveal(goal)
            try wait(NSPredicate(format: "value == %@", "1440"), on: goal,
                     message: "Eight cups at 180 mL should convert to a 1440 mL goal")
            try selectTab("今日")
            try selectTab("偏好设置")
            try reveal(goal)
            try wait(NSPredicate(format: "value == %@", "1440"), on: goal,
                     message: "Switching pages must retain the goal draft without converting twice")

            XCTAssertFalse(app.buttons["saveSettingsButton"].exists)
            app.terminate()
            app.launch()
            try selectTab("偏好设置")
            try reveal(goal)
            try wait(NSPredicate(format: "value == %@", "1440"), on: goal,
                     message: "Goal change must survive a cold launch without saving manually")
            screenshot("Settings-AutoSaved")
            try reveal(capacity, swipeUp: false)
            try wait(NSPredicate(format: "value == %@", "180"), on: capacity,
                     message: "Saved capacity should remain 180")
            screenshot("Settings-Saved-180-mL")
        }

        try XCTContext.runActivity(named: "Dashboard: preserve old volumes and add two 180 mL cups") { _ in
            try selectTab("今日")
            try assertTotal("3 杯")
            for count in 4...5 {
                try tap(app.buttons["addCupButton"])
                try assertTotal("\(count) 杯")
            }
            screenshot("Dashboard-5-Cups")
            try assertGoal("今天饮水目标 5/8杯")
            try tap(totalAmountButton)
            try assertTotal("1110 mL")
            let progressLabel = app.staticTexts.matching(NSPredicate(
                format: "label CONTAINS %@", "今天饮水目标 1110/1440mL"
            )).firstMatch
            try waitForExistence(progressLabel)
            screenshot("Dashboard-1110-mL")
        }

        try XCTContext.runActivity(named: "History: today's total and individual cup volumes") { _ in
            try selectTab("历史记录")
            let today = Date().formatted(
                .dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day()
            )
            // History supplies an explicit date-based accessibility label, not a guessed
            // concatenation of the visible labels in its HStack.
            let todayRecord = app.buttons.matching(NSPredicate(
                format: "label CONTAINS %@ AND label CONTAINS %@", today, "1110 mL"
            )).firstMatch
            try reveal(todayRecord)
            try wait(NSPredicate(format: "label CONTAINS %@", "1110 mL"), on: todayRecord,
                     message: "Today's history total should be 1110 mL")
            screenshot("History-Today-1110-mL")
            if todayRecord.label.contains("查看详情") {
                try tap(todayRecord)
            }
            try wait(NSPredicate(format: "label CONTAINS %@", "收起详情"), on: todayRecord,
                     message: "Today's history details should be expanded")

            let formattedTotal = 1_110.formatted(.number.locale(Locale(identifier: "zh_CN")))
            let summary = app.staticTexts.matching(NSPredicate(
                format: "label == %@", "5 杯 · 合计 \(formattedTotal) mL"
            )).firstMatch
            try reveal(summary)
            screenshot("History-Today-5-Cups-Details")
            let cups = app.staticTexts.matching(NSPredicate(format: "label == %@", "一杯水"))
            let oldVolumes = app.staticTexts.matching(NSPredicate(format: "label == %@", "250 mL"))
            let newVolumes = app.staticTexts.matching(NSPredicate(format: "label == %@", "180 mL"))
            let details = NSPredicate { _, _ in
                cups.count == 5 && oldVolumes.count == 3 && newVolumes.count == 2
            }
            try wait(details, on: app,
                     message: "History must contain five cups: three 250 mL and two 180 mL records")
            try reveal(newVolumes.firstMatch)
            screenshot("History-180-mL-Cup-Details")
            try reveal(oldVolumes.firstMatch)
            screenshot("History-250-mL-Cup-Details")
        }

        try XCTContext.runActivity(named: "Dashboard: confirm undo of the most recent cup") { _ in
            try selectTab("今日")
            try assertTotal("1110 mL")
            let undo = app.buttons.matching(NSPredicate(format: "label == %@", "撤销一杯")).firstMatch
            try tap(undo)
            let confirm = app.buttons.matching(NSPredicate(format: "label == %@", "撤销最近一杯")).firstMatch
            try waitForExistence(confirm)
            screenshot("Dashboard-Undo-Confirmation")
            try tap(confirm)
            try assertTotal("930 mL")
            screenshot("Dashboard-Undo-930-mL")
            try tap(totalAmountButton)
            try assertTotal("4 杯")
            screenshot("Dashboard-Undo-4-Cups")
            // Persist mL as the display preference before testing a cold relaunch.
            try tap(totalAmountButton)
            try assertTotal("930 mL")
        }

        try XCTContext.runActivity(named: "Relaunch: retain 930 mL, four cups, and 180 mL capacity") { _ in
            app.terminate()
            app.launch()
            try assertTotal("930 mL")
            screenshot("Dashboard-Relaunch-930-mL")
            try tap(totalAmountButton)
            try assertTotal("4 杯")
            screenshot("Dashboard-Relaunch-4-Cups")
            try tap(totalAmountButton)
            try assertTotal("930 mL")
            let addCup = app.buttons["addCupButton"]
            try reveal(addCup)
            try wait(NSPredicate(format: "label CONTAINS %@", "180"), on: addCup,
                     message: "New cups should still use the saved 180 mL capacity")
            try selectTab("偏好设置")
            let capacity = app.textFields["cupCapacityField"]
            try reveal(capacity, swipeUp: false)
            try wait(NSPredicate(format: "value == %@", "180"), on: capacity,
                     message: "A cold relaunch should retain the saved 180 mL capacity")
            screenshot("Settings-Relaunch-180-mL")
            try selectTab("今日")
            try assertTotal("930 mL")
            screenshot("Dashboard-Final-930-mL")
        }
    }

    func testDashboardUnitSwitchKeepsLayout() throws {
        app.launch()
        try selectTab("今日")

        let todayHeading = app.staticTexts["今日记录"]
        let weekHeading = app.staticTexts["每周饮水"]
        try reveal(weekHeading)
        try waitForExistence(todayHeading)
        XCTAssertLessThan(todayHeading.frame.maxY, weekHeading.frame.minY,
                          "Today's records must appear above the weekly chart")

        try reveal(totalAmountButton, swipeUp: false)
        let amountFrame = totalAmountButton.frame
        let goalLabel = app.staticTexts["goalProgressLabel"]
        try waitForExistence(goalLabel)
        let goalFrame = goalLabel.frame
        let addButton = app.buttons["addCupButton"]
        try waitForExistence(addButton)
        let actionsTop = addButton.frame.minY
        screenshot("Dashboard-StableLayout-Before")

        for index in 1...4 {
            let previousLabel = totalAmountButton.label
            try tap(totalAmountButton)
            try wait(NSPredicate(format: "label != %@", previousLabel), on: totalAmountButton,
                     message: "Tapping the total must switch units")
            let stableLayout = NSPredicate { _, _ in
                let current = self.totalAmountButton.frame
                return abs(current.minX - amountFrame.minX) < 1
                    && abs(current.minY - amountFrame.minY) < 1
                    && abs(current.width - amountFrame.width) < 1
                    && abs(current.height - amountFrame.height) < 1
                    && abs(goalLabel.frame.minY - goalFrame.minY) < 1
                    && abs(goalLabel.frame.maxY - goalFrame.maxY) < 1
                    && abs(addButton.frame.minY - actionsTop) < 1
            }
            try wait(stableLayout, on: app,
                     message: "Unit switching must not resize the card or move the controls below it")
            screenshot("Dashboard-StableLayout-Switch-\(index)")
        }
    }

    func testWeeklyHistoryNavigationAndUnits() throws {
        app.launch()
        try selectTab("偏好设置")
        try reveal(app.staticTexts["显示单位"])
        try selectTab("历史记录")
        XCTAssertFalse(app.staticTexts["显示单位"].exists)
        let average = app.descendants(matching: .any)["weeklyAverageStatistic"].firstMatch
        try reveal(average)
        let range = app.staticTexts["weekRangeLabel"]
        try waitForExistence(range)
        let currentRange = range.label
        XCTAssertTrue(currentRange.hasPrefix("本周"))
        let previous = app.buttons["previousWeekButton"]
        let next = app.buttons["nextWeekButton"]
        XCTAssertFalse(next.isEnabled)
        screenshot("WeeklyHistory-CurrentWeek")

        let picker = app.segmentedControls["displayUnitPicker"]
        try tap(picker.buttons["mL"])
        try wait(NSPredicate(format: "label ENDSWITH %@", "mL"), on: average,
                 message: "Weekly average must follow the selected display unit")
        try tap(picker.buttons["杯"])
        try wait(NSPredicate(format: "label ENDSWITH %@", "杯"), on: average,
                 message: "Weekly average must switch back to cups")

        let pager = app.scrollViews["weeklyChartPager"]
        try waitForExistence(pager)
        // A dedicated simulator can be seeded with multiple weeks before this test.
        // Fresh installations still exercise both navigation boundaries.
        if previous.isEnabled {
            pager.swipeRight()
            try wait(NSPredicate(format: "label != %@", currentRange), on: range,
                     message: "Swiping right must show the previous calendar week")
            let previousRange = range.label
            XCTAssertTrue(next.isEnabled)
            screenshot("WeeklyHistory-SwipedToPreviousWeek")
            try tap(next)
            try wait(NSPredicate(format: "label == %@", currentRange), on: range,
                     message: "Next week must return to the current week")
            try tap(previous)
            try wait(NSPredicate(format: "label == %@", previousRange), on: range,
                     message: "Button and swipe navigation must select the same week")
            pager.swipeLeft()
            try wait(NSPredicate(format: "label == %@", currentRange), on: range,
                     message: "Swiping left must return to the current week")
        }
        pager.swipeLeft()
        XCTAssertEqual(range.label, currentRange)
        XCTAssertFalse(next.isEnabled)

        var visited = 0
        while previous.isEnabled && visited < 12 {
            let before = range.label
            try tap(previous)
            try wait(NSPredicate(format: "label != %@", before), on: range,
                     message: "Each previous action must move by a calendar week")
            visited += 1
        }
        XCTAssertFalse(previous.isEnabled, "The dedicated test fixture must end at its oldest recorded week")
        let oldestRange = range.label
        pager.swipeRight()
        XCTAssertEqual(range.label, oldestRange)
        screenshot("WeeklyHistory-OldestWeekBoundary")
        for _ in 0..<visited { try tap(next) }
        try wait(NSPredicate(format: "label == %@", currentRange), on: range,
                 message: "Navigating forward must return to the current week")
        screenshot("WeeklyHistory-ReturnedToCurrentWeek")
    }

    private func assertGoal(_ text: String) throws {
        let label = app.staticTexts["goalProgressLabel"]
        try reveal(label, swipeUp: false)
        try wait(NSPredicate(format: "label == %@", text), on: label,
                 message: "Goal should follow the current display unit: \(text)")
    }

    private var totalAmountButton: XCUIElement {
        app.buttons["totalAmountButton"]
    }

    private func assertTotal(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try reveal(totalAmountButton, swipeUp: false, file: file, line: line)
        try wait(NSPredicate(format: "label CONTAINS %@", text), on: totalAmountButton,
                 message: "Dashboard total should contain \(text)", file: file, line: line)
    }

    private func selectTab(_ title: String) throws {
        // iOS 27 exposes its floating tab container as Other, while its items remain Buttons.
        try tap(app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        try reveal(element, file: file, line: line)
        try wait(NSPredicate(format: "enabled == true AND hittable == true"), on: element,
                 message: "Control must be enabled and hittable: \(element)", file: file, line: line)
        element.tap()
    }

    private func reveal(_ element: XCUIElement, swipeUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            if !scrollView.exists { break }
            if swipeUp { scrollView.swipeUp() } else { scrollView.swipeDown() }
        }
        try waitForExistence(element, file: file, line: line)
        try wait(NSPredicate(format: "hittable == true"), on: element,
                 message: "Element should be visible after scrolling: \(element)", file: file, line: line)
    }

    private func waitForExistence(_ element: XCUIElement,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("Missing UI element: \(element)", file: file, line: line)
            throw WorkflowError.assertionFailed
        }
    }

    private func wait(_ predicate: NSPredicate, on object: Any, message: String,
                      file: StaticString = #filePath, line: UInt = #line) throws {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        guard XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed else {
            XCTFail(message, file: file, line: line)
            throw WorkflowError.assertionFailed
        }
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
