import Foundation
import XCTest
@testable import OpenAwayCore

final class AppSettingsTests: XCTestCase {
    func testDefaultsImplementTwentyTwentyRule() {
        let settings = AppSettings()
        XCTAssertEqual(settings.breakIntervalMinutes, 20)
        XCTAssertEqual(settings.breakDurationSeconds, 20)
        XCTAssertTrue(settings.idlePauseEnabled)
        XCTAssertTrue(settings.pauseForMeetings)
        XCTAssertTrue(settings.pauseForVideo)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testNormalizationSafelyBoundsExtremeInputs() {
        var settings = AppSettings()
        settings.breakIntervalMinutes = Int.min
        settings.breakDurationSeconds = Int.max
        settings.longBreakEvery = 0
        settings.longBreakDurationMinutes = Int.max
        settings.idleThresholdMinutes = -1
        settings.blinkIntervalMinutes = Int.max
        settings.postureIntervalMinutes = Int.min
        settings.normalize()
        XCTAssertEqual(settings.breakIntervalMinutes, 1)
        XCTAssertEqual(settings.breakDurationSeconds, 600)
        XCTAssertEqual(settings.longBreakEvery, 1)
        XCTAssertEqual(settings.longBreakDurationMinutes, 60)
        XCTAssertEqual(settings.idleThresholdMinutes, 1)
        XCTAssertEqual(settings.blinkIntervalMinutes, 60)
        XCTAssertEqual(settings.postureIntervalMinutes, 1)
    }

    func testNormalizationSanitizesDisplaySettingsAndDeduplicatesExclusions() {
        var settings = AppSettings()
        settings.appearance = "invalid"
        settings.breakTheme = "invalid"
        settings.breakMessage = " \n "
        settings.excludedBundleIDs = [" com.apple.Keynote ", "", "com.apple.Keynote", "com.apple.Terminal"]
        settings.normalize()
        XCTAssertEqual(settings.appearance, "system")
        XCTAssertEqual(settings.breakTheme, "grove")
        XCTAssertEqual(settings.breakMessage, "Look up. Breathe out.")
        XCTAssertEqual(settings.excludedBundleIDs, ["com.apple.Keynote", "com.apple.Terminal"])
        settings.breakMessage = String(repeating: "🌿", count: 200)
        settings.normalize()
        XCTAssertEqual(settings.breakMessage.count, 160)
    }

    func testOlderSettingsDecodeWithNewDefaultsAndNormalizeValues() throws {
        let data = Data(#"{"breakIntervalMinutes":10,"breakDurationSeconds":-4}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.breakIntervalMinutes, 10)
        XCTAssertEqual(settings.breakDurationSeconds, 5)
        XCTAssertEqual(settings.breakTheme, "grove")
        XCTAssertTrue(settings.longBreakEnabled)
        XCTAssertTrue(settings.pauseForMeetings)
        XCTAssertTrue(settings.pauseForVideo)
    }

    func testSettingsAndHistoryRoundTrip() throws {
        var settings = AppSettings()
        settings.breakMessage = "Let your eyes wander."
        settings.excludedBundleIDs = ["com.apple.Keynote"]
        settings.pauseForMeetings = false
        settings.pauseForVideo = false
        let encoded = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: encoded), settings)

        let record = BreakRecord(date: Date(timeIntervalSince1970: 100), durationSeconds: 20, kind: .short, completed: true)
        let history = try JSONEncoder().encode([record])
        XCTAssertEqual(try JSONDecoder().decode([BreakRecord].self, from: history), [record])
    }

    func testBlurThemeRoundTripsAndObsoleteHeadsUpSettingIsIgnored() throws {
        let data = Data(#"{"breakTheme":"blur","headsUpSeconds":300}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.breakTheme, "blur")
        XCTAssertEqual(BreakEngine.headsUpSeconds, 5)
        let encoded = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: encoded), settings)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("headsUpSeconds"))
    }

    func testEngineNormalizesSettingsAtEntry() {
        var settings = AppSettings()
        settings.breakIntervalMinutes = -20
        var engine = BreakEngine(settings: settings)
        XCTAssertEqual(engine.remainingSeconds, 60)
        settings.breakIntervalMinutes = Int.max
        engine.updateSettings(settings, now: Date())
        XCTAssertEqual(engine.settings.breakIntervalMinutes, 180)
    }
}
