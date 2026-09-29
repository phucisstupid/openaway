import AppKit
import Combine
import CoreGraphics
import OpenAwayCore
import ServiceManagement
import UniformTypeIdentifiers

enum ReminderKind: String {
    case headsUp, posture, blink
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet { settingsDidChange(oldValue: oldValue) }
    }
    @Published private(set) var engine: BreakEngine
    @Published private(set) var records: [BreakRecord]
    @Published var selectedPage = "overview"
    @Published var reminderText: String?
    @Published private(set) var reminderKind: ReminderKind = .posture
    @Published private(set) var isReminderPreview = false
    @Published var launchAtLoginError: String?
    @Published private(set) var isPreviewing = false
    @Published private(set) var escapeArmed = false

    weak var coordinator: AppDelegate?
    private let defaults: UserDefaults
    private let persists: Bool
    private let activityMonitor = ActivityMonitor()
    private var timer: Timer?
    private var synchronizingSettings = false
    private var manuallyPaused = false
    private var manualPauseUntil: Date?
    private var pausedDuringRest = false
    private var pausedForIdle = false
    private var isSleeping = false
    private var isDisplaySleeping = false
    private var isLocked = false
    private var lastPulse = Date()
    private var blinkElapsed: TimeInterval = 0
    private var postureElapsed: TimeInterval = 0
    private var reminderExpiresAt: Date?
    private var escapeExpiresAt: Date?

    init(defaults: UserDefaults = .standard, persists: Bool = true) {
        self.defaults = defaults
        self.persists = persists
        var restored = persists ? Self.decode(AppSettings.self, key: "settings.v1", defaults: defaults) ?? AppSettings() : AppSettings()
        restored.normalize()
        if persists {
            restored.launchAtLogin = SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval
        }
        settings = restored
        engine = BreakEngine(settings: restored)
        records = persists ? Self.decode([BreakRecord].self, key: "history.v1", defaults: defaults) ?? [] : []
        if persists && SMAppService.mainApp.status == .requiresApproval {
            launchAtLoginError = "Allow OpenAway in System Settings → General → Login Items."
        }
    }

    func begin() {
        guard timer == nil else { return }
        lastPulse = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pulse() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        pulse()
    }

    func stop() { timer?.invalidate(); timer = nil }

    var todayRecords: [BreakRecord] { records.filter { Calendar.current.isDateInToday($0.date) } }
    var isShowingHeadsUp: Bool { engine.phase == .preparing && !isPreviewing }
    var completedToday: Int { todayRecords.filter(\.completed).count }
    var restedTodaySeconds: Int { todayRecords.filter(\.completed).reduce(0) { $0 + $1.durationSeconds } }
    var streakDays: Int {
        let calendar = Calendar.current
        let dates = Set(records.filter(\.completed).map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: Date())
        if !dates.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) { day = yesterday }
        var count = 0
        while dates.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    func startBreak(kind: BreakKind = .short) {
        isPreviewing = false
        manuallyPaused = false
        manualPauseUntil = nil
        pausedForIdle = false
        dismissReminder()
        consume(engine.startBreak(now: Date(), kind: kind))
        refreshPresentation()
    }

    func snooze(minutes: Int) {
        if isPreviewing { closePreview(); return }
        // Adding time to a paused focus timer preserves the user's pause intent.
        if engine.phase != .paused || pausedDuringRest {
            manuallyPaused = false
            manualPauseUntil = nil
            pausedForIdle = false
        }
        consume(engine.snooze(minutes: minutes, now: Date()))
        dismissReminder()
        refreshPresentation()
    }

    func skipBreak() {
        if isPreviewing { closePreview(); return }
        consume(engine.skipBreak(now: Date()))
        dismissReminder()
        refreshPresentation()
    }

    func handleEscape(isRepeat: Bool = false, now: Date = Date()) {
        guard !isRepeat else { return }
        if isPreviewing { closePreview(); return }
        guard engine.phase == .resting else { return }
        if let expiry = escapeExpiresAt, now < expiry {
            skipBreak()
        } else {
            escapeExpiresAt = now.addingTimeInterval(2)
            escapeArmed = true
        }
    }

    func togglePause() {
        if engine.phase == .paused { resume() } else { pause(minutes: nil) }
    }

    func pause(minutes: Int?) {
        closePreview()
        manuallyPaused = true
        manualPauseUntil = minutes.map { Date().addingTimeInterval(TimeInterval(max(1, $0) * 60)) }
        synchronizePause(now: Date())
        dismissReminder()
        refreshPresentation()
    }

    func resume() {
        manuallyPaused = false
        manualPauseUntil = nil
        synchronizePause(now: Date())
        refreshPresentation()
    }

    func resetSettings() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        settings = AppSettings()
    }
    func clearHistory() { records = []; persistHistory() }
    func dismissReminder() {
        reminderText = nil
        isReminderPreview = false
        reminderExpiresAt = nil
        coordinator?.synchronizeReminder()
    }
    func previewReminder(_ kind: ReminderKind) {
        let text: String
        switch kind {
        case .headsUp: text = "A short pause for your eyes is coming soon."
        case .posture: text = "Let your shoulders drop. Sit comfortably."
        case .blink: text = "Close your eyes gently, then open them slowly."
        }
        showReminder(kind, text: text, now: Date(), preview: true)
    }
    func showDashboard() { coordinator?.showDashboard() }

    func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Pause when this app is active"
        panel.prompt = "Add App"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier,
              id != Bundle.main.bundleIdentifier,
              !settings.excludedBundleIDs.contains(id) else { return }
        settings.excludedBundleIDs.append(id)
    }

    func removeExcludedApp(_ id: String) { settings.excludedBundleIDs.removeAll { $0 == id } }

    func previewBreak() {
        // A preview only changes presentation. The real session continues untouched.
        guard engine.phase != .resting else { refreshPresentation(); return }
        isPreviewing = true
        dismissReminder()
        refreshPresentation()
    }

    func closePreview() {
        guard isPreviewing else { return }
        isPreviewing = false
        refreshPresentation()
    }

    func setSleeping(_ value: Bool) {
        isSleeping = value
        if value { closePreview(); dismissReminder() }
        lastPulse = Date()
        synchronizePause(now: Date())
        refreshPresentation()
    }

    func setLocked(_ value: Bool) {
        isLocked = value
        if value { closePreview(); dismissReminder() }
        lastPulse = Date()
        synchronizePause(now: Date())
        refreshPresentation()
    }

    func setDisplaySleeping(_ value: Bool) {
        isDisplaySleeping = value
        if value { closePreview(); dismissReminder() }
        lastPulse = Date()
        synchronizePause(now: Date())
        refreshPresentation()
    }

    func activeApplicationChanged() {
        synchronizePause(now: Date())
        refreshPresentation()
    }

    private func pulse(now: Date = Date(), inputIdleSeconds: TimeInterval? = nil) {
        let idle = inputIdleSeconds ?? Self.inputIdleSeconds
        let elapsed = max(0, min(now.timeIntervalSince(lastPulse), 2))
        lastPulse = now
        synchronizePause(now: now, inputIdleSeconds: idle)
        consume(engine.tick(now: now, allowAutomaticBreak: idle.isFinite && idle >= 5 && !isPreviewing))
        if engine.phase == .focusing && !isReminderPreview {
            blinkElapsed += elapsed
            postureElapsed += elapsed
            if reminderText == nil && settings.postureReminderEnabled && postureElapsed >= Double(settings.postureIntervalMinutes * 60) {
                postureElapsed = 0
                showReminder(.posture, text: "Let your shoulders drop. Sit comfortably.", now: now)
            } else if reminderText == nil && settings.blinkReminderEnabled && blinkElapsed >= Double(settings.blinkIntervalMinutes * 60) {
                blinkElapsed = 0
                showReminder(.blink, text: "Close your eyes gently, then open them slowly.", now: now)
            }
        }
        if let expiry = reminderExpiresAt, now >= expiry { dismissReminder() }
        if let expiry = escapeExpiresAt, now >= expiry {
            escapeExpiresAt = nil
            escapeArmed = false
        }
        refreshPresentation()
    }

    private static var inputIdleSeconds: TimeInterval {
        // Read activity timing only: no event tap, keystrokes, or input permission.
        // A held mouse button also counts as working, even while the pointer is still.
        if [CGMouseButton.left, .right, .center].contains(where: {
            CGEventSource.buttonState(.combinedSessionState, button: $0)
        }) { return 0 }
        let anyInput = CGEventType(rawValue: UInt32.max)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private func synchronizePause(now: Date, inputIdleSeconds: TimeInterval? = nil) {
        let idle = inputIdleSeconds ?? Self.inputIdleSeconds
        if let until = manualPauseUntil, now >= until {
            manuallyPaused = false
            manualPauseUntil = nil
        }
        let resting = engine.phase == .resting || (engine.phase == .paused && pausedDuringRest)
        var reason: String?
        if isSleeping || isDisplaySleeping { reason = "Computer is asleep" }
        else if isLocked { reason = "Screen is locked" }
        else if manuallyPaused { reason = manualPauseUntil == nil ? "Paused by you" : "Taking a pause" }
        else if !resting,
                let active = NSWorkspace.shared.frontmostApplication,
                let id = active.bundleIdentifier,
                settings.excludedBundleIDs.contains(id) {
            reason = "Paused for \(active.localizedName ?? "an excluded app")"
        } else if !resting, let activity = activityMonitor.pauseReason(settings: settings, now: now) {
            reason = activity
        } else if !resting && settings.idlePauseEnabled {
            if idle.isFinite && idle >= Double(settings.idleThresholdMinutes * 60) {
                reason = "Away from your Mac"
                pausedForIdle = true
            }
        }
        if let reason {
            if engine.phase != .paused { pausedDuringRest = engine.phase == .resting }
            if engine.phase != .paused || engine.pauseReason != reason {
                consume(engine.pause(now: now, reason: reason, until: nil))
                dismissReminder()
            }
        } else if engine.phase == .paused {
            consume(engine.resume(now: now, reset: pausedForIdle && settings.resetAfterIdle && !pausedDuringRest,
                                  allowAutomaticBreak: idle.isFinite && idle >= 5 && !isPreviewing))
            pausedDuringRest = false
            pausedForIdle = false
        }
    }

    private func consume(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .headsUp:
                // The advance notice follows the preparing phase, including waiting
                // at zero. It has no expiry and is restored after pauses or previews.
                dismissReminder()
            case .breakStarted:
                isPreviewing = false
                dismissReminder()
                blinkElapsed = 0
                if settings.soundEnabled { NSSound(named: NSSound.Name("Glass"))?.play() }
            case .breakFinished(let record):
                records.append(record)
                // Keep several years of ordinary daily use without unbounded storage.
                if records.count > 20_000 { records.removeFirst(records.count - 20_000) }
                persistHistory()
                if record.completed && settings.soundEnabled { NSSound(named: NSSound.Name("Pop"))?.play() }
            }
        }
    }

    private func showReminder(_ kind: ReminderKind, text: String, now: Date, preview: Bool = false) {
        guard !isPreviewing && engine.phase != .resting && (preview || engine.phase != .paused) else { return }
        reminderKind = kind
        isReminderPreview = preview
        reminderText = text
        reminderExpiresAt = now.addingTimeInterval(kind == .headsUp ? 10 : 7)
        coordinator?.synchronizeReminder()
    }

    static func reminderSmokeCheck() -> Bool {
        let model = AppModel(persists: false)
        model.settings.pauseForMeetings = false
        model.settings.pauseForVideo = false
        model.settings.idlePauseEnabled = false
        model.settings.blinkReminderEnabled = true
        model.blinkElapsed = Double(model.settings.blinkIntervalMinutes * 60)
        model.postureElapsed = Double(model.settings.postureIntervalMinutes * 60)
        model.pulse()
        guard model.reminderKind == .posture, model.reminderText != nil else { return false }
        model.pulse()
        guard model.reminderKind == .posture else { return false }
        model.dismissReminder()
        model.pulse()
        return model.reminderKind == .blink && model.reminderText != nil
    }

    static func resetSettingsSmokeCheck() -> Bool {
        let model = AppModel(persists: false)
        model.settings.soundEnabled = false
        model.settings.breakIntervalMinutes = 45
        model.settings.breakTheme = "blur"
        model.settings.breakMessage = "Custom message"
        model.settings.excludedBundleIDs = ["org.example.Focus"]
        model.startBreak()
        model.skipBreak()
        let history = model.records
        model.resetSettings()
        return model.settings == AppSettings() && model.records == history && !history.isEmpty
    }

    func countdownSmokeCheck(presentationMatches: () -> Bool) -> Bool {
        stop()
        let now = Date().addingTimeInterval(-30)
        engine = BreakEngine(settings: settings, now: now.addingTimeInterval(-Double(settings.breakIntervalMinutes * 60)))
        pulse(now: now, inputIdleSeconds: 0)
        guard isShowingHeadsUp, engine.remainingSeconds == 5, presentationMatches() else { return false }
        pulse(now: now.addingTimeInterval(5), inputIdleSeconds: 0)
        guard isShowingHeadsUp, engine.remainingSeconds == 0, presentationMatches() else { return false }
        pulse(now: now.addingTimeInterval(20), inputIdleSeconds: 4.9)
        guard isShowingHeadsUp, records.isEmpty, presentationMatches() else { return false }
        pause(minutes: nil)
        guard !isShowingHeadsUp, presentationMatches() else { return false }
        manuallyPaused = false
        let resumedAt = Date()
        synchronizePause(now: resumedAt, inputIdleSeconds: 0)
        refreshPresentation()
        guard isShowingHeadsUp, presentationMatches() else { return false }
        previewBreak()
        guard isPreviewing, presentationMatches() else { return false }
        closePreview()
        guard isShowingHeadsUp, presentationMatches() else { return false }
        pulse(now: resumedAt.addingTimeInterval(1), inputIdleSeconds: 5)
        guard engine.phase == .resting, engine.remainingSeconds == settings.breakDurationSeconds,
              presentationMatches() else { return false }
        skipBreak()
        clearHistory()
        return presentationMatches()
    }

    private func refreshPresentation() {
        if engine.phase != .resting || isPreviewing {
            escapeExpiresAt = nil
            if escapeArmed { escapeArmed = false }
        }
        coordinator?.synchronizeBreakWindows()
        coordinator?.synchronizeReminder()
        coordinator?.updateStatusItem()
    }

    private func settingsDidChange(oldValue: AppSettings) {
        guard !synchronizingSettings else { return }
        synchronizingSettings = true
        settings.normalize()
        engine.updateSettings(settings, now: Date())
        if oldValue.blinkReminderEnabled != settings.blinkReminderEnabled { blinkElapsed = 0 }
        if oldValue.postureReminderEnabled != settings.postureReminderEnabled { postureElapsed = 0 }
        if oldValue.launchAtLogin != settings.launchAtLogin && persists { updateLoginItem() }
        if persists, let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings.v1") }
        synchronizingSettings = false
        coordinator?.applyAppearance()
        synchronizePause(now: Date())
        refreshPresentation()
    }

    private func updateLoginItem() {
        launchAtLoginError = nil
        do {
            if settings.launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                if SMAppService.mainApp.status == .requiresApproval {
                    launchAtLoginError = "Allow OpenAway in System Settings → General → Login Items."
                }
            } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLoginError = "Could not update launch at login. Keep OpenAway in Applications and try again. \(error.localizedDescription)"
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func persistHistory() {
        if persists, let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: "history.v1") }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
