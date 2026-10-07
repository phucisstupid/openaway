import Foundation

/// All user preferences. Decoding older preferences preserves defaults for new keys.
public struct AppSettings: Codable, Equatable, Sendable {
    public var breakIntervalMinutes = 20
    public var breakDurationSeconds = 20
    public var longBreakEnabled = true
    public var longBreakEvery = 4
    public var longBreakDurationMinutes = 5
    public var idlePauseEnabled = true
    public var pauseForMeetings = true
    public var pauseForVideo = true
    public var idleThresholdMinutes = 2
    public var resetAfterIdle = true
    public var soundEnabled = true
    public var blinkReminderEnabled = false
    public var blinkIntervalMinutes = 5
    public var postureReminderEnabled = true
    public var postureIntervalMinutes = 30
    public var showCountdownInMenuBar = true
    public var launchAtLogin = false
    public var appearance = "system"
    public var breakTheme = "blur"
    public var breakImagePath: String?
    public var breakImageName: String?
    public var breakImageBlurRadius = 0.0
    public var breakMessage = "Look up. Breathe out."
    public var excludedBundleIDs: [String] = []

    public init() {}

    public mutating func normalize() {
        breakIntervalMinutes = min(max(breakIntervalMinutes, 1), 180)
        breakDurationSeconds = min(max(breakDurationSeconds, 5), 600)
        longBreakEvery = min(max(longBreakEvery, 1), 12)
        longBreakDurationMinutes = min(max(longBreakDurationMinutes, 1), 60)
        idleThresholdMinutes = min(max(idleThresholdMinutes, 1), 60)
        blinkIntervalMinutes = min(max(blinkIntervalMinutes, 1), 60)
        postureIntervalMinutes = min(max(postureIntervalMinutes, 1), 180)
        if !["system", "light", "dark"].contains(appearance) { appearance = "system" }
        if breakTheme == "wallpaper" { breakTheme = "blurImage" }
        if breakTheme == "picture" {
            breakTheme = "blurImage"
            breakImageBlurRadius = 0
        }
        if !["blur", "blurImage"].contains(breakTheme) { breakTheme = "blur" }
        breakImageBlurRadius = breakImageBlurRadius.isFinite ? min(max(breakImageBlurRadius, 0), 80) : 0
        breakMessage = String(breakMessage.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        if breakMessage.isEmpty { breakMessage = "Look up. Breathe out." }
        var seen = Set<String>()
        excludedBundleIDs = excludedBundleIDs.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && seen.insert(trimmed).inserted ? trimmed : nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case breakIntervalMinutes, breakDurationSeconds, longBreakEnabled, longBreakEvery
        case longBreakDurationMinutes, idlePauseEnabled, idleThresholdMinutes
        case pauseForMeetings, pauseForVideo
        case resetAfterIdle, soundEnabled, blinkReminderEnabled, blinkIntervalMinutes
        case postureReminderEnabled, postureIntervalMinutes, showCountdownInMenuBar
        case launchAtLogin, appearance, breakTheme, breakImagePath, breakImageName, breakImageBlurRadius, breakMessage, excludedBundleIDs
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        breakIntervalMinutes = try values.decodeIfPresent(Int.self, forKey: .breakIntervalMinutes) ?? breakIntervalMinutes
        breakDurationSeconds = try values.decodeIfPresent(Int.self, forKey: .breakDurationSeconds) ?? breakDurationSeconds
        longBreakEnabled = try values.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? longBreakEnabled
        longBreakEvery = try values.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? longBreakEvery
        longBreakDurationMinutes = try values.decodeIfPresent(Int.self, forKey: .longBreakDurationMinutes) ?? longBreakDurationMinutes
        idlePauseEnabled = try values.decodeIfPresent(Bool.self, forKey: .idlePauseEnabled) ?? idlePauseEnabled
        pauseForMeetings = try values.decodeIfPresent(Bool.self, forKey: .pauseForMeetings) ?? pauseForMeetings
        pauseForVideo = try values.decodeIfPresent(Bool.self, forKey: .pauseForVideo) ?? pauseForVideo
        idleThresholdMinutes = try values.decodeIfPresent(Int.self, forKey: .idleThresholdMinutes) ?? idleThresholdMinutes
        resetAfterIdle = try values.decodeIfPresent(Bool.self, forKey: .resetAfterIdle) ?? resetAfterIdle
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? soundEnabled
        blinkReminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .blinkReminderEnabled) ?? blinkReminderEnabled
        blinkIntervalMinutes = try values.decodeIfPresent(Int.self, forKey: .blinkIntervalMinutes) ?? blinkIntervalMinutes
        postureReminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .postureReminderEnabled) ?? postureReminderEnabled
        postureIntervalMinutes = try values.decodeIfPresent(Int.self, forKey: .postureIntervalMinutes) ?? postureIntervalMinutes
        showCountdownInMenuBar = try values.decodeIfPresent(Bool.self, forKey: .showCountdownInMenuBar) ?? showCountdownInMenuBar
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        appearance = try values.decodeIfPresent(String.self, forKey: .appearance) ?? appearance
        breakTheme = try values.decodeIfPresent(String.self, forKey: .breakTheme) ?? breakTheme
        breakImagePath = try values.decodeIfPresent(String.self, forKey: .breakImagePath)
        breakImageName = try values.decodeIfPresent(String.self, forKey: .breakImageName)
        breakImageBlurRadius = try values.decodeIfPresent(Double.self, forKey: .breakImageBlurRadius) ?? breakImageBlurRadius
        breakMessage = try values.decodeIfPresent(String.self, forKey: .breakMessage) ?? breakMessage
        excludedBundleIDs = try values.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? excludedBundleIDs
        normalize()
    }
}
