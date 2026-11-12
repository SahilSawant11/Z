//
//  ExpenseCompanionUITests.swift
//  ExpenseCompanionUITests
//
//  End-to-end flows for the Germany MS plan and university tracker.
//  The app is launched with `-uiTesting`, which gives it a fresh in-memory
//  store (seeded with the default plan on first open) and skips reminders.
//

import XCTest

final class ExpenseCompanionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]

        // Dismiss any system permission prompt (location/notifications) if one appears.
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for title in ["Don’t Allow", "Don't Allow", "Allow While Using App", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launch()
    }

    // MARK: - Cost timeline

    /// Marking a cost paid deducts it from "Saved so far"; un-paying puts it back.
    func testMarkingCostPaidMovesMoneyOutOfSavingsAndBack() {
        openGermanyPlan()

        let savings = app.textFields["field-Saved so far"]
        XCTAssertTrue(savings.waitForExistence(timeout: 5))
        XCTAssertEqual(savings.value as? String, "0")

        let ielts = element("cost-IELTS")
        reveal(ielts)
        ielts.press(forDuration: 1.0)
        app.buttons["Mark paid"].tap()

        XCTAssertTrue(ielts.label.contains("PAID"), "row should show PAID, got: \(ielts.label)")
        reveal(savings, upward: true)
        XCTAssertTrue((savings.value as? String ?? "").contains("19,000"),
                      "savings should drop by ₹19,000, got: \(savings.value ?? "nil")")

        reveal(ielts)
        ielts.press(forDuration: 1.0)
        app.buttons["Mark unpaid"].tap()

        reveal(savings, upward: true)
        XCTAssertEqual(savings.value as? String, "0")
    }

    /// Tapping a cost opens the editor; a saved rename shows in the timeline.
    func testEditingACostUpdatesTheTimeline() {
        openGermanyPlan()

        let documents = element("cost-Documents")
        reveal(documents)
        documents.tap()

        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        title.typeText("Document fees")
        app.buttons["Save"].tap()

        let renamed = element("cost-Document fees")
        reveal(renamed)
        XCTAssertTrue(renamed.exists)
        XCTAssertFalse(element("cost-Documents").exists)
    }

    // MARK: - Loan

    /// Changing the loan tenure recalculates the EMI.
    func testChangingLoanTenureChangesEMI() {
        openGermanyPlan()

        let emi = app.staticTexts["stat-EMI"]
        reveal(emi)
        let before = emi.label

        let assumptions = app.buttons["Assumptions"]
        reveal(assumptions)
        assumptions.tap()

        let tenure = app.steppers.element(boundBy: 1)
        reveal(tenure)
        tenure.buttons["Increment"].tap()

        reveal(emi, upward: true)
        XCTAssertNotEqual(emi.label, before, "EMI should change when tenure changes")
    }

    // MARK: - University tracker

    /// Adding a program shows it in the list; long-press changes its status.
    func testAddingProgramAndChangingStatus() {
        openGermanyPlan()
        openUniversities()

        addProgram("TU Munich")

        let row = element("program-TU Munich")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(row.label.contains("APPLIED"))

        row.press(forDuration: 1.0)
        app.buttons["Applied"].tap()
        XCTAssertTrue(row.label.contains("APPLIED"), "row should show APPLIED, got: \(row.label)")
    }

    /// Two uni-assist programs = €75 + €30 = €105 ≈ ₹9,450 at ₹90/€, synced into the plan.
    func testSyncingFeesUpdatesTheCostTimeline() {
        openGermanyPlan()
        openUniversities()

        addProgram("RWTH Aachen")
        addProgram("TU Berlin")

        let sync = app.buttons["sync-fees"]
        XCTAssertTrue(sync.waitForExistence(timeout: 5))
        sync.tap()
        XCTAssertTrue(sync.label.contains("updated"), "button should confirm, got: \(sync.label)")

        app.navigationBars.buttons.firstMatch.tap()   // back to the plan

        let synced = element("cost-Applications × 2")
        reveal(synced)
        XCTAssertTrue(synced.exists, "synced cost should replace the uni-assist estimate")
        XCTAssertTrue(synced.label.contains("9,450"), "expected ₹9,450, got: \(synced.label)")
        XCTAssertFalse(element("cost-uni-assist × 10").exists)
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func openGermanyPlan() {
        app.buttons["Goals"].tap()
        let card = element("germany-plan-card")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.navigationBars["Germany MS"].waitForExistence(timeout: 5))
    }

    private func openUniversities() {
        let card = element("universities-card")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.navigationBars["Universities"].waitForExistence(timeout: 5))
    }

    private func addProgram(_ name: String) {
        app.buttons["Add program"].firstMatch.tap()
        let university = app.textFields.firstMatch
        XCTAssertTrue(university.waitForExistence(timeout: 5))
        university.tap()
        university.typeText(name)
        app.buttons["Save"].tap()
        XCTAssertTrue(element("program-\(name)").waitForExistence(timeout: 5))
    }

    /// Scrolls until the element is on screen and hittable.
    private func reveal(_ el: XCUIElement, upward: Bool = false) {
        var attempts = 0
        while !(el.exists && el.isHittable) && attempts < 10 {
            upward ? app.swipeDown() : app.swipeUp()
            attempts += 1
        }
    }
}
