import Foundation

public enum BreakKind: String, Codable, Equatable, Sendable {
    case short, long
}

public enum SessionPhase: Equatable, Sendable {
    case focusing, preparing, resting, paused
}

public struct BreakRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// The time this break ended.
    public var date: Date
    /// Active rest time, excluding time spent paused.
    public var durationSeconds: Int
    public var kind: BreakKind
    public var completed: Bool

    public init(id: UUID = UUID(), date: Date, durationSeconds: Int, kind: BreakKind, completed: Bool) {
        self.id = id
        self.date = date
        self.durationSeconds = max(0, durationSeconds)
        self.kind = kind
        self.completed = completed
    }
}

public enum EngineEvent: Equatable, Sendable {
    case headsUp
    case breakStarted(BreakKind)
    case breakFinished(BreakRecord)
}

/// A deterministic timer state machine. The host supplies time and performs side effects.
/// Deadlines prevent a delayed timer callback from slowing the countdown. A newly
/// presented break always starts at `now`, so a late callback cannot consume unseen rest.
public struct BreakEngine: Sendable {
    public static let headsUpSeconds = 5

    public private(set) var settings: AppSettings
    public private(set) var phase: SessionPhase = .focusing
    public private(set) var currentBreakKind: BreakKind = .short
    public private(set) var completedBreaks = 0
    public private(set) var pauseReason: String?

    private var deadline: Date
    private var observedTime: Date
    private var timerDuration: TimeInterval
    private var shortBreaksSinceLong = 0
    private var hasSentHeadsUp = false
    private var suspendedPhase: SessionPhase?
    private var suspendedRemaining: TimeInterval?
    private var resumeAt: Date?

    public var remainingSeconds: Int { Int(ceil(remainingInterval)) }

    /// Elapsed fraction of the current focus or rest timer.
    public var progress: Double {
        guard timerDuration > 0 else { return 1 }
        return min(1, max(0, 1 - remainingInterval / timerDuration))
    }

    private var remainingInterval: TimeInterval {
        let remaining = suspendedRemaining ?? deadline.timeIntervalSince(observedTime)
        return min(timerDuration, max(0, remaining))
    }

    private var effectivePhase: SessionPhase { suspendedPhase ?? phase }

    public init(settings: AppSettings = AppSettings(), now: Date = Date()) {
        var normalized = settings
        normalized.normalize()
        self.settings = normalized
        self.observedTime = now
        self.timerDuration = TimeInterval(normalized.breakIntervalMinutes * 60)
        self.deadline = now.addingTimeInterval(timerDuration)
    }

    public mutating func tick(now: Date, allowAutomaticBreak: Bool = true) -> [EngineEvent] {
        observedTime = now
        if phase == .paused {
            guard let resumeAt, now >= resumeAt else { return [] }
            // Resume at the promised deadline even if this callback arrives late.
            restorePausedTimer(at: resumeAt)
            observedTime = now
        }
        switch phase {
        case .focusing, .preparing:
            if remainingInterval <= TimeInterval(Self.headsUpSeconds), !hasSentHeadsUp {
                hasSentHeadsUp = true
                phase = .preparing
                // Even a late callback must give the user the full visible warning.
                deadline = now.addingTimeInterval(TimeInterval(Self.headsUpSeconds))
                return [.headsUp]
            }
            if remainingInterval <= 0, allowAutomaticBreak {
                return beginBreak(now: now, kind: nextBreakKind)
            }
        case .resting:
            if remainingInterval <= 0 {
                let record = makeRecord(now: now, completed: true)
                completedBreaks += 1
                if currentBreakKind == .short { shortBreaksSinceLong += 1 } else { shortBreaksSinceLong = 0 }
                beginFocus(now: now)
                return [.breakFinished(record)]
            }
        case .paused:
            break
        }
        return []
    }

    public mutating func updateSettings(_ settings: AppSettings, now: Date) {
        observedTime = now
        var normalized = settings
        normalized.normalize()
        let oldSettings = self.settings
        let elapsed = timerDuration - remainingInterval
        self.settings = normalized

        var newDuration: TimeInterval?
        if effectivePhase == .resting {
            if currentBreakKind == .short, oldSettings.breakDurationSeconds != normalized.breakDurationSeconds {
                newDuration = TimeInterval(normalized.breakDurationSeconds)
            } else if currentBreakKind == .long,
                oldSettings.longBreakDurationMinutes != normalized.longBreakDurationMinutes
            {
                newDuration = TimeInterval(normalized.longBreakDurationMinutes * 60)
            }
        } else {
            currentBreakKind = nextBreakKind
            if oldSettings.breakIntervalMinutes != normalized.breakIntervalMinutes {
                newDuration = TimeInterval(normalized.breakIntervalMinutes * 60)
            }
        }
        if let newDuration {
            timerDuration = newDuration
            let remaining = max(0, newDuration - elapsed)
            if phase == .paused { suspendedRemaining = remaining } else { deadline = now.addingTimeInterval(remaining) }
        }
        if effectivePhase == .preparing, remainingInterval > TimeInterval(Self.headsUpSeconds) {
            // A longer interval can move an already announced break back into focus.
            // Re-arm the heads-up so it is announced at the new deadline as well.
            if phase == .paused { suspendedPhase = .focusing } else { phase = .focusing }
            hasSentHeadsUp = false
        }
    }

    public mutating func startBreak(now: Date, kind: BreakKind = .short) -> [EngineEvent] {
        observedTime = now
        // Repeated menu actions must not restart a break or create duplicate records.
        if effectivePhase == .resting {
            return phase == .paused ? resume(now: now) : tick(now: now)
        }
        return beginBreak(now: now, kind: kind)
    }

    public mutating func snooze(minutes: Int, now: Date) -> [EngineEvent] {
        observedTime = now
        let delay = TimeInterval(min(max(minutes, 1), 180) * 60)
        if effectivePhase == .resting {
            let record = makeRecord(now: now, completed: false)
            beginFocus(now: now, duration: delay)
            return [.breakFinished(record)]
        }
        // During focus, "delay five minutes" means adding time to the current
        // schedule. Retain elapsed focus time in the progress denominator.
        let extendedRemaining = remainingInterval + delay
        timerDuration += delay
        hasSentHeadsUp = false
        if phase == .paused {
            suspendedRemaining = extendedRemaining
            suspendedPhase = .focusing
        } else {
            phase = .focusing
            deadline = now.addingTimeInterval(extendedRemaining)
        }
        return []
    }

    public mutating func skipBreak(now: Date) -> [EngineEvent] {
        observedTime = now
        let events: [EngineEvent] =
            effectivePhase == .resting
            ? [.breakFinished(makeRecord(now: now, completed: false))] : []
        beginFocus(now: now)
        return events
    }

    public mutating func pause(now: Date, reason: String = "Paused", until: Date? = nil) -> [EngineEvent] {
        observedTime = now
        if phase != .paused {
            suspendedRemaining = remainingInterval
            suspendedPhase = phase
            phase = .paused
        }
        pauseReason = reason
        resumeAt = until.map { max(now, $0) }
        return []
    }

    public mutating func resume(now: Date, reset: Bool = false, allowAutomaticBreak: Bool = true) -> [EngineEvent] {
        observedTime = now
        guard phase == .paused else { return [] }
        if reset {
            let events: [EngineEvent] =
                effectivePhase == .resting
                ? [.breakFinished(makeRecord(now: now, completed: false))] : []
            beginFocus(now: now)
            return events
        }
        restorePausedTimer(at: now)
        return tick(now: now, allowAutomaticBreak: allowAutomaticBreak)
    }

    private var nextBreakKind: BreakKind {
        settings.longBreakEnabled && shortBreaksSinceLong >= settings.longBreakEvery ? .long : .short
    }

    private mutating func beginBreak(now: Date, kind: BreakKind) -> [EngineEvent] {
        clearPause()
        phase = .resting
        currentBreakKind = kind
        observedTime = now
        timerDuration =
            kind == .short
            ? TimeInterval(settings.breakDurationSeconds)
            : TimeInterval(settings.longBreakDurationMinutes * 60)
        deadline = now.addingTimeInterval(timerDuration)
        return [.breakStarted(kind)]
    }

    private mutating func beginFocus(now: Date, duration: TimeInterval? = nil) {
        clearPause()
        phase = .focusing
        currentBreakKind = nextBreakKind
        observedTime = now
        timerDuration = duration ?? TimeInterval(settings.breakIntervalMinutes * 60)
        deadline = now.addingTimeInterval(timerDuration)
        hasSentHeadsUp = false
    }

    private mutating func restorePausedTimer(at now: Date) {
        phase = suspendedPhase ?? .focusing
        deadline = now.addingTimeInterval(suspendedRemaining ?? timerDuration)
        clearPause()
        observedTime = now
    }

    private mutating func clearPause() {
        suspendedPhase = nil
        suspendedRemaining = nil
        pauseReason = nil
        resumeAt = nil
    }

    private func makeRecord(now: Date, completed: Bool) -> BreakRecord {
        BreakRecord(
            date: now,
            durationSeconds: Int(completed ? timerDuration : floor(timerDuration - remainingInterval)),
            kind: currentBreakKind,
            completed: completed
        )
    }
}
