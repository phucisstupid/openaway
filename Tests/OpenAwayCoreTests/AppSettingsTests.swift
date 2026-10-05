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
        XCTAssertEqual(settings.breakTheme, "blur")
        XCTAssertNil(settings.breakImagePath)
        XCTAssertNil(settings.breakImageName)
        XCTAssertEqual(settings.breakImageBlurRadius, 32)
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
        XCTAssertEqual(settings.breakTheme, "blur")
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
        XCTAssertEqual(settings.breakTheme, "blur")
        XCTAssertNil(settings.breakImagePath)
        XCTAssertNil(settings.breakImageName)
        XCTAssertEqual(settings.breakImageBlurRadius, 32)
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

    func testLegacyPictureThemeKeepsImageAndSharpAppearance() throws {
        let data = Data(#"{"breakTheme":"picture","breakImagePath":"/Users/example/Library/Application Support/OpenAway/BreakImage.jpg","breakImageName":"Mountain.jpg","breakImageBlurRadius":48}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.breakTheme, "blurImage")
        XCTAssertEqual(settings.breakImageBlurRadius, 0)
        XCTAssertEqual(settings.breakImagePath, "/Users/example/Library/Application Support/OpenAway/BreakImage.jpg")
        XCTAssertEqual(settings.breakImageName, "Mountain.jpg")
        let encoded = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: encoded), settings)
    }

    func testBlurImageThemeAndRadiusRoundTrip() throws {
        var settings = AppSettings()
        settings.breakTheme = "blurImage"
        settings.breakImageBlurRadius = 47.5
        settings.normalize()
        XCTAssertEqual(settings.breakTheme, "blurImage")
        XCTAssertEqual(settings.breakImageBlurRadius, 47.5)
        let encoded = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: encoded), settings)
    }

    func testLegacyWallpaperThemeMigratesToBlurImage() throws {
        let data = Data(#"{"breakTheme":"wallpaper"}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.breakTheme, "blurImage")
        XCTAssertEqual(settings.breakImageBlurRadius, 32)
    }

    func testImageBlurRadiusClampsAndRejectsNonfiniteValues() {
        for (input, expected) in [(-1.0, 0.0), (81.0, 80.0), (0.0, 0.0), (80.0, 80.0),
                                  (Double.nan, 32.0), (Double.infinity, 32.0), (-Double.infinity, 32.0)] {
            var settings = AppSettings()
            settings.breakImageBlurRadius = input
            settings.normalize()
            XCTAssertEqual(settings.breakImageBlurRadius, expected)
        }
    }

    func testRemovedBuiltInThemesInOlderSettingsMigrateToBlur() throws {
        for theme in ["grove", "ocean", "dusk"] {
            let data = try JSONSerialization.data(withJSONObject: ["breakTheme": theme])
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            XCTAssertEqual(settings.breakTheme, "blur")
            XCTAssertNil(settings.breakImagePath)
            XCTAssertNil(settings.breakImageName)
        }
    }

    func testInvalidDecodedThemeFallsBackToBlur() throws {
        let data = Data(#"{"breakTheme":"unknown"}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.breakTheme, "blur")
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
