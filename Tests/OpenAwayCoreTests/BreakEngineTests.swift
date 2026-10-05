import Foundation
import XCTest
@testable import OpenAwayCore

final class BreakEngineTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func time(_ seconds: TimeInterval) -> Date { origin.addingTimeInterval(seconds) }

    private func makeEngine() -> BreakEngine {
        var settings = AppSettings()
        settings.breakIntervalMinutes = 1
        settings.breakDurationSeconds = 20
        settings.longBreakEvery = 2
        settings.longBreakDurationMinutes = 1
        return BreakEngine(settings: settings, now: origin)
    }

    private func finishedRecord(_ events: [EngineEvent], file: StaticString = #filePath, line: UInt = #line) throws -> BreakRecord {
        XCTAssertEqual(events.count, 1, file: file, line: line)
        guard case .breakFinished(let record) = events.first else {
            XCTFail("Expected a finished break record", file: file, line: line)
            throw NSError(domain: "BreakEngineTests", code: 1)
        }
        return record
    }

    func testInitialFocusUsesSettings() {
        let engine = makeEngine()
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.currentBreakKind, .short)
    }

    func testHeadsUpIsEmittedOnlyOnceAndBreakStartsAtDeadline() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(54)), [])
        XCTAssertEqual(engine.tick(now: time(55)), [.headsUp])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.tick(now: time(59)), [])
        XCTAssertEqual(engine.tick(now: time(60)), [.breakStarted(.short)])
        XCTAssertEqual(engine.phase, .resting)
        XCTAssertEqual(engine.remainingSeconds, 20)
        XCTAssertEqual(engine.progress, 0)
    }

    func testLateHeadsUpAlwaysHasFiveVisibleSeconds() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(58.5)), [.headsUp])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 5)
        XCTAssertEqual(engine.tick(now: time(63.4)), [])
        XCTAssertEqual(engine.tick(now: time(63.5)), [.breakStarted(.short)])
    }

    func testDelayedCallbackUsesDeadlineAndStartsAFullVisibleBreak() throws {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(4_000)), [.headsUp])
        XCTAssertEqual(engine.remainingSeconds, 5)
        XCTAssertEqual(engine.tick(now: time(4_005)), [.breakStarted(.short)])
        XCTAssertEqual(engine.remainingSeconds, 20)
        let record = try finishedRecord(engine.tick(now: time(9_000)))
        XCTAssertTrue(record.completed)
        XCTAssertEqual(record.durationSeconds, 20)
        XCTAssertEqual(record.date, time(9_000))
        XCTAssertEqual(engine.completedBreaks, 1)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.tick(now: time(9_000)), [])
    }

    func testCountdownUsesCeilingWithoutAccumulatingCallbackDrift() {
        var engine = makeEngine()
        _ = engine.tick(now: time(1.2))
        XCTAssertEqual(engine.remainingSeconds, 59)
        XCTAssertEqual(engine.progress, 0.02, accuracy: 0.00001)
        _ = engine.tick(now: time(42.8))
        XCTAssertEqual(engine.remainingSeconds, 18)
        XCTAssertEqual(engine.progress, 42.8 / 60, accuracy: 0.00001)
    }

    func testLongBreakFollowsCompletedShortBreaksAndResetsCycle() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: time(0))
        _ = engine.tick(now: time(20))
        XCTAssertEqual(engine.currentBreakKind, .short)
        _ = engine.startBreak(now: time(21))
        _ = engine.tick(now: time(41))
        XCTAssertEqual(engine.currentBreakKind, .long)
        XCTAssertEqual(engine.tick(now: time(96)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(101)), [.breakStarted(.long)])
        XCTAssertEqual(engine.remainingSeconds, 60)
        let record = try finishedRecord(engine.tick(now: time(161)))
        XCTAssertEqual(record.kind, .long)
        XCTAssertEqual(record.durationSeconds, 60)
        XCTAssertEqual(engine.completedBreaks, 3)
        XCTAssertEqual(engine.currentBreakKind, .short)
    }

    func testSkippedAndSnoozedBreaksDoNotAdvanceLongBreakCycle() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: time(0))
        let skipped = try finishedRecord(engine.skipBreak(now: time(7)))
        XCTAssertFalse(skipped.completed)
        XCTAssertEqual(skipped.durationSeconds, 7)
        _ = engine.startBreak(now: time(10))
        let snoozed = try finishedRecord(engine.snooze(minutes: 5, now: time(18)))
        XCTAssertFalse(snoozed.completed)
        XCTAssertEqual(snoozed.durationSeconds, 8)
        XCTAssertEqual(engine.remainingSeconds, 300)
        XCTAssertEqual(engine.completedBreaks, 0)
        XCTAssertEqual(engine.currentBreakKind, .short)
    }

    func testDisabledLongBreaksKeepSchedulingShortBreaks() {
        var engine = makeEngine()
        var settings = engine.settings
        settings.longBreakEnabled = false
        engine.updateSettings(settings, now: origin)
        for count in 0..<3 {
            _ = engine.startBreak(now: time(Double(count * 30)))
            _ = engine.tick(now: time(Double(count * 30 + 20)))
        }
        XCTAssertEqual(engine.completedBreaks, 3)
        XCTAssertEqual(engine.currentBreakKind, .short)
    }

    func testSkippingFocusDoesNotCreateARecord() {
        var engine = makeEngine()
        XCTAssertEqual(engine.skipBreak(now: time(35)), [])
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.snooze(minutes: 5, now: time(40)), [])
        XCTAssertEqual(engine.remainingSeconds, 355)
        XCTAssertEqual(engine.completedBreaks, 0)
    }

    func testSnoozeInputCannotOverflowOrCreateNegativeCountdown() {
        var engine = makeEngine()
        _ = engine.snooze(minutes: Int.max, now: origin)
        XCTAssertEqual(engine.remainingSeconds, 10_860)
        _ = engine.snooze(minutes: Int.min, now: origin)
        XCTAssertEqual(engine.remainingSeconds, 10_920)
    }

    func testFocusSnoozeAddsTimeInsteadOfAdvancingTheBreak() {
        var engine = BreakEngine(now: origin)
        _ = engine.tick(now: time(60))
        XCTAssertEqual(engine.remainingSeconds, 19 * 60)
        XCTAssertEqual(engine.snooze(minutes: 5, now: time(60)), [])
        XCTAssertEqual(engine.remainingSeconds, 24 * 60)
        XCTAssertEqual(engine.progress, 60.0 / (25 * 60), accuracy: 0.00001)
        XCTAssertEqual(engine.tick(now: time(25 * 60 - 5)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(25 * 60)), [.breakStarted(.short)])
    }

    func testSnoozingPausedFocusExtendsFrozenTimeWithoutResuming() {
        var engine = makeEngine()
        _ = engine.pause(now: time(10), reason: "Meeting")
        XCTAssertEqual(engine.snooze(minutes: 5, now: time(100)), [])
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.pauseReason, "Meeting")
        XCTAssertEqual(engine.remainingSeconds, 350)
        _ = engine.resume(now: time(200))
        XCTAssertEqual(engine.remainingSeconds, 350)
        XCTAssertEqual(engine.tick(now: time(545)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(550)), [.breakStarted(.short)])
    }

    func testSnoozingPreparingFocusRearmsHeadsUpAtDelayedDeadline() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55)), [.headsUp])
        XCTAssertEqual(engine.snooze(minutes: 5, now: time(55)), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 305)
        XCTAssertEqual(engine.tick(now: time(354)), [])
        XCTAssertEqual(engine.tick(now: time(355)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(360)), [.breakStarted(.short)])
    }

    func testSnoozingPausedRestRecordsOnlyActiveRestAndSchedulesDelay() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: origin)
        _ = engine.pause(now: time(7))
        let record = try finishedRecord(engine.snooze(minutes: 5, now: time(100)))
        XCTAssertFalse(record.completed)
        XCTAssertEqual(record.durationSeconds, 7)
        XCTAssertEqual(engine.completedBreaks, 0)
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 300)
        XCTAssertNil(engine.pauseReason)
        XCTAssertEqual(engine.tick(now: time(395)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(400)), [.breakStarted(.short)])
    }

    func testPauseFreezesFocusAndRepeatedPauseOnlyChangesReason() {
        var engine = makeEngine()
        XCTAssertEqual(engine.pause(now: time(15), reason: "Idle"), [])
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remainingSeconds, 45)
        _ = engine.tick(now: time(300))
        _ = engine.pause(now: time(350), reason: "Meeting")
        XCTAssertEqual(engine.remainingSeconds, 45)
        XCTAssertEqual(engine.pauseReason, "Meeting")
        _ = engine.resume(now: time(400))
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertNil(engine.pauseReason)
        _ = engine.tick(now: time(410))
        XCTAssertEqual(engine.remainingSeconds, 35)
    }

    func testPreparingPauseRetainsHeadsUpWithoutRepeatingIt() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55)), [.headsUp])
        _ = engine.pause(now: time(57))
        XCTAssertEqual(engine.resume(now: time(100)), [])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 3)
        XCTAssertEqual(engine.tick(now: time(103)), [.breakStarted(.short)])
    }

    func testTimedPauseResumesAtItsDeadlineEvenWhenTickArrivesLate() {
        var engine = makeEngine()
        _ = engine.pause(now: time(10), until: time(100))
        XCTAssertEqual(engine.tick(now: time(99)), [])
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.tick(now: time(110)), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 40)
        XCTAssertEqual(engine.tick(now: time(145)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(150)), [.breakStarted(.short)])
    }

    func testChangingPauseToIndefiniteClearsAutomaticResume() {
        var engine = makeEngine()
        _ = engine.pause(now: time(10), until: time(100))
        _ = engine.pause(now: time(50), reason: "Sleeping")
        _ = engine.tick(now: time(1_000))
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remainingSeconds, 50)
    }

    func testPauseDuringBreakExcludesPausedTimeFromHistory() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: origin)
        _ = engine.pause(now: time(5))
        _ = engine.resume(now: time(500))
        let record = try finishedRecord(engine.skipBreak(now: time(503)))
        XCTAssertEqual(record.durationSeconds, 8)
        XCTAssertFalse(record.completed)
        XCTAssertEqual(engine.completedBreaks, 0)
    }

    func testPausedBreakCanCompleteAfterTimedResume() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: origin)
        _ = engine.pause(now: time(5), until: time(100))
        let record = try finishedRecord(engine.tick(now: time(120)))
        XCTAssertTrue(record.completed)
        XCTAssertEqual(record.durationSeconds, 20)
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
    }

    func testIdleResetRestartsFocusAndRecordsInterruptedRest() throws {
        var engine = makeEngine()
        _ = engine.startBreak(now: origin)
        _ = engine.pause(now: time(6))
        let record = try finishedRecord(engine.resume(now: time(100), reset: true))
        XCTAssertFalse(record.completed)
        XCTAssertEqual(record.durationSeconds, 6)
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.completedBreaks, 0)
    }

    func testManualStartIsIdempotentDuringRestAndResumesPausedRest() {
        var engine = makeEngine()
        XCTAssertEqual(engine.startBreak(now: origin), [.breakStarted(.short)])
        XCTAssertEqual(engine.startBreak(now: time(5)), [])
        XCTAssertEqual(engine.remainingSeconds, 15)
        _ = engine.pause(now: time(8))
        XCTAssertEqual(engine.startBreak(now: time(100)), [])
        XCTAssertEqual(engine.phase, .resting)
        XCTAssertEqual(engine.remainingSeconds, 12)
    }

    func testScheduleEditsPreserveElapsedFocusAndApplyOnNextTick() {
        var engine = makeEngine()
        var settings = engine.settings
        settings.breakIntervalMinutes = 2
        engine.updateSettings(settings, now: time(30))
        XCTAssertEqual(engine.remainingSeconds, 90)
        XCTAssertEqual(engine.progress, 0.25)
        settings.breakIntervalMinutes = 1
        engine.updateSettings(settings, now: time(65))
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.tick(now: time(65)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(70)), [.breakStarted(.short)])
    }

    func testUnrelatedSettingsDoNotReplaceSnooze() {
        var engine = makeEngine()
        _ = engine.snooze(minutes: 5, now: origin)
        var settings = engine.settings
        settings.breakTheme = "wallpaper"
        engine.updateSettings(settings, now: time(30))
        XCTAssertEqual(engine.remainingSeconds, 330)
    }

    func testExtendingIntervalAfterHeadsUpRearmsWarningAtNewDeadline() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55)), [.headsUp])
        var settings = engine.settings
        settings.breakIntervalMinutes = 2
        engine.updateSettings(settings, now: time(55))
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 65)
        XCTAssertEqual(engine.tick(now: time(115)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(120)), [.breakStarted(.short)])
    }

    func testEditingPausedPreparingTimerRearmsWarningAfterResume() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.pause(now: time(55))
        var settings = engine.settings
        settings.breakIntervalMinutes = 2
        engine.updateSettings(settings, now: time(100))
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remainingSeconds, 65)
        XCTAssertEqual(engine.resume(now: time(200)), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.tick(now: time(260)), [.headsUp])
    }

    func testUnrelatedSettingsDoNotRestartTheHeadsUpCountdown() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55)), [.headsUp])
        var settings = engine.settings
        settings.breakTheme = "blur"
        engine.updateSettings(settings, now: time(57))
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 3)
        XCTAssertEqual(engine.tick(now: time(60)), [.breakStarted(.short)])
    }

    func testDueBreakWaitsForActivityGateWithoutRepeatingHeadsUp() throws {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55), allowAutomaticBreak: false), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(60), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.progress, 1)
        XCTAssertEqual(engine.tick(now: time(3_600), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.completedBreaks, 0)
        XCTAssertEqual(engine.tick(now: time(3_605), allowAutomaticBreak: true), [.breakStarted(.short)])
        XCTAssertEqual(engine.remainingSeconds, 20)
        XCTAssertEqual(engine.progress, 0)
        let record = try finishedRecord(engine.tick(now: time(3_625), allowAutomaticBreak: false))
        XCTAssertTrue(record.completed)
        XCTAssertEqual(record.durationSeconds, 20)
    }

    func testActivityGateDoesNotEndTheHeadsUpEarly() {
        var engine = makeEngine()
        XCTAssertEqual(engine.tick(now: time(55), allowAutomaticBreak: false), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(57), allowAutomaticBreak: true), [])
        XCTAssertEqual(engine.remainingSeconds, 3)
        XCTAssertEqual(engine.tick(now: time(60), allowAutomaticBreak: true), [.breakStarted(.short)])
    }

    func testManualBreakStartsImmediatelyWhileWaitingForActivity() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55), allowAutomaticBreak: false)
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        XCTAssertEqual(engine.startBreak(now: time(61), kind: .long), [.breakStarted(.long)])
        XCTAssertEqual(engine.phase, .resting)
        XCTAssertEqual(engine.remainingSeconds, 60)
    }

    func testResumingDueBreakHonorsActivityGate() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        _ = engine.pause(now: time(61), reason: "Meeting")
        XCTAssertEqual(engine.resume(now: time(100), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.tick(now: time(105)), [.breakStarted(.short)])
    }

    func testTimedResumeOfDueBreakHonorsActivityGate() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        _ = engine.pause(now: time(61), until: time(100))
        XCTAssertEqual(engine.tick(now: time(120), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.tick(now: time(125)), [.breakStarted(.short)])
        XCTAssertEqual(engine.remainingSeconds, 20)
    }

    func testLateTimedResumeProvidesFullHeadsUpBeforeWaiting() {
        var engine = makeEngine()
        _ = engine.pause(now: time(50), until: time(100))
        XCTAssertEqual(engine.tick(now: time(300), allowAutomaticBreak: false), [.headsUp])
        XCTAssertEqual(engine.remainingSeconds, 5)
        XCTAssertEqual(engine.tick(now: time(305), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.tick(now: time(310)), [.breakStarted(.short)])
    }

    func testSnoozingWaitingBreakSchedulesNewCountdownWithoutRecordingRest() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        XCTAssertEqual(engine.snooze(minutes: 5, now: time(600)), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 300)
        XCTAssertEqual(engine.completedBreaks, 0)
        XCTAssertEqual(engine.tick(now: time(895)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(900)), [.breakStarted(.short)])
    }

    func testSkippingWaitingBreakStartsFreshFocusWithoutRecordingRest() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        XCTAssertEqual(engine.skipBreak(now: time(600)), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.completedBreaks, 0)
        XCTAssertEqual(engine.tick(now: time(655)), [.headsUp])
    }

    func testResettingPausedWaitingBreakStartsFreshFocus() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        _ = engine.pause(now: time(61))
        XCTAssertEqual(engine.resume(now: time(600), reset: true, allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.completedBreaks, 0)
    }

    func testSettingsChangesWhileWaitingPreserveOrRescheduleDueBreak() {
        var engine = makeEngine()
        _ = engine.tick(now: time(55))
        _ = engine.tick(now: time(60), allowAutomaticBreak: false)
        var settings = engine.settings
        settings.breakTheme = "blur"
        engine.updateSettings(settings, now: time(600))
        XCTAssertEqual(engine.phase, .preparing)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.tick(now: time(600), allowAutomaticBreak: false), [])
        settings.breakIntervalMinutes = 2
        engine.updateSettings(settings, now: time(601))
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.tick(now: time(656)), [.headsUp])
        XCTAssertEqual(engine.tick(now: time(661), allowAutomaticBreak: false), [])
        XCTAssertEqual(engine.tick(now: time(666)), [.breakStarted(.short)])
    }

    func testEditingPausedDurationPreservesActiveElapsedTime() {
        var engine = makeEngine()
        _ = engine.startBreak(now: origin)
        _ = engine.pause(now: time(5))
        var settings = engine.settings
        settings.breakDurationSeconds = 30
        engine.updateSettings(settings, now: time(100))
        XCTAssertEqual(engine.remainingSeconds, 25)
        _ = engine.resume(now: time(200))
        _ = engine.tick(now: time(210))
        XCTAssertEqual(engine.remainingSeconds, 15)
    }

    func testClockMovingBackwardsCannotProduceInvalidProgress() {
        var engine = makeEngine()
        _ = engine.tick(now: time(-100))
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.progress, 0)
    }
}
