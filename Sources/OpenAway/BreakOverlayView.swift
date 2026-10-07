import SwiftUI
import OpenAwayCore

struct BreakOverlayView: View {
    @ObservedObject var model: AppModel
    private var seconds: Int { model.isPreviewing ? model.settings.breakDurationSeconds : model.engine.remainingSeconds }
    private var longBreak: Bool { !model.isPreviewing && model.engine.currentBreakKind == .long }
    private var textColor: Color { .white }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BreakBackgroundView(model: model)

                VStack(spacing: 28) {
                    Text(longBreak ? "Time to stretch." : model.settings.breakMessage)
                        .font(.system(size: min(64, max(34, geometry.size.width * 0.045)), weight: .semibold))
                        .lineLimit(3).minimumScaleFactor(0.75)
                    Text(longBreak ? "Stand up and move around until the countdown is over." : "Set your eyes on something distant until the countdown is over.")
                        .font(.system(size: 19, weight: .medium)).foregroundStyle(textColor.opacity(0.88))
                    Rectangle().fill(textColor.opacity(0.30)).frame(width: 96, height: 1)
                        .padding(.top, 12)
                    Text(timeString(seconds))
                        .font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(textColor.opacity(0.90))
                        .accessibilityLabel("\(seconds) seconds remaining")
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1000)
                .padding(.horizontal, 48)

                VStack {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label(context.date.formatted(.dateTime.hour().minute()), systemImage: "clock")
                            .font(.system(size: 16, weight: .medium)).monospacedDigit()
                            .foregroundStyle(textColor.opacity(0.85))
                    }
                    .padding(.top, 44)
                    Spacer()
                    if model.isPreviewing {
                        Text("Break preview").font(.caption).foregroundStyle(textColor.opacity(0.70))
                    }
                    HStack(spacing: 12) {
                        if model.isPreviewing {
                            Button { model.closePreview() } label: {
                                Label("Close preview", systemImage: "xmark")
                            }
                        } else {
                            Button { model.skipBreak() } label: {
                                Label("Skip break", systemImage: "forward")
                            }
                            Button { model.snooze(minutes: 5) } label: {
                                Label("Snooze 5 min", systemImage: "clock.arrow.circlepath")
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle()).controlSize(.large)
                    .breakButtonShape()
                    Text(model.isPreviewing ? "Press Esc to close" : model.escapeArmed ? "Press Esc again to skip" : "Press Esc twice to skip the break")
                        .font(.caption.weight(model.escapeArmed ? .semibold : .regular))
                        .foregroundStyle(textColor.opacity(model.escapeArmed ? 1 : 0.65))
                        .accessibilityAddTraits(model.escapeArmed ? .updatesFrequently : [])
                        .padding(.top, 5)
                }
                .padding(.bottom, 36)
            }
            .foregroundStyle(textColor)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

struct WellnessReminderView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var hoveredMinutes: Int?
    private var title: String {
        switch model.reminderKind {
        case .headsUp: return "A little pause is coming."
        case .posture: return "Relax your shoulders."
        case .blink: return "A slow blink."
        }
    }
    var body: some View {
        Group {
            if model.isShowingHeadsUp {
                headsUp
            } else {
                wellnessReminder
            }
        }
        .padding(14)
        .preferredColorScheme(model.settings.appearance == "dark" ? .dark : model.settings.appearance == "light" ? .light : nil)
        // The nonactivating panel keeps typing focus elsewhere, but its controls are available.
        .environment(\.controlActiveState, .key)
    }

    private var headsUp: some View {
        let waiting = model.engine.remainingSeconds <= 0
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 15) {
                Image(systemName: waiting ? "pause" : "clock")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [Color.pink.opacity(0.65), Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(waiting ? "Waiting for a pause" : timeString(model.engine.remainingSeconds))
                        .font(.system(size: 23, weight: .semibold)).monospacedDigit()
                        .accessibilityLabel(waiting ? "Waiting for a pause" : "Break in \(model.engine.remainingSeconds) seconds")
                    Text(waiting ? "Starts after 3 seconds without typing or mouse activity." : "Almost time. Finish your thought—we’ll wait for a pause.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Button("Start now") { model.startBreak(kind: model.engine.currentBreakKind) }
                    .buttonStyle(PrimaryButtonStyle())
                    .brightness(hoveredMinutes == 0 ? hoverBrightness : 0)
                    .onHover { if $0 || hoveredMinutes == 0 { hoveredMinutes = $0 ? 0 : nil } }
                ForEach([1, 5, 15], id: \.self) { minutes in
                    Button("+\(minutes)m") { model.snooze(minutes: minutes) }
                        .buttonStyle(SecondaryButtonStyle())
                        .brightness(hoveredMinutes == minutes ? hoverBrightness : 0)
                        .onHover { if $0 || hoveredMinutes == minutes { hoveredMinutes = $0 ? minutes : nil } }
                        .accessibilityLabel("Snooze \(minutes) minutes")
                }
            }
            .controlSize(.large).breakButtonShape()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: hoveredMinutes)
        }
        .padding(20).frame(width: 460, alignment: .leading).nativeGlass(cornerRadius: 28)
        .onDisappear { hoveredMinutes = nil }
    }

    private var hoverBrightness: Double {
        let dark = model.settings.appearance == "dark" || (model.settings.appearance == "system" && colorScheme == .dark)
        return dark ? 0.08 : -0.05
    }

    private var wellnessReminder: some View {
        HStack(spacing: 18) {
            ReminderSymbol(kind: model.reminderKind, active: model.reminderText != nil).frame(width: 52, height: 64)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(model.reminderKind == .headsUp && !model.isReminderPreview ? "Your break starts in \(model.engine.remainingSeconds) seconds." : model.reminderText ?? "Take a comfortable breath.")
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if model.reminderKind == .headsUp && !model.isReminderPreview {
                    HStack {
                        Button("Start now") { model.startBreak(kind: model.engine.currentBreakKind) }
                        Button("+5 min") { model.snooze(minutes: 5) }
                    }.buttonStyle(.bordered).controlSize(.small)
                } else if model.isReminderPreview {
                    Text("Preview").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Button { model.dismissReminder() } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold)).padding(5)
            }.buttonStyle(.plain).foregroundStyle(.secondary).help("Dismiss reminder")
                .accessibilityLabel("Dismiss reminder")
        }.padding(22).frame(width: 432, alignment: .leading)
            .nativeGlass(cornerRadius: 24)
    }
}

private extension View {
    @ViewBuilder
    func breakButtonShape() -> some View {
        if #available(macOS 14.0, *) {
            self.buttonBorderShape(.capsule)
        } else {
            self.buttonBorderShape(.roundedRectangle)
        }
    }
}

private struct ReminderSymbol: View {
    let kind: ReminderKind
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || kind == .headsUp)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let blink = seconds.truncatingRemainder(dividingBy: 3)
            let movement = reduceMotion ? 0 : sin(seconds * 2)
            Image(systemName: kind == .blink ? "eye" : kind == .posture ? "figure.stand" : "leaf")
                .font(.system(size: kind == .posture ? 43 : 35, weight: .light))
                .foregroundStyle(.tint)
                .scaleEffect(x: 1, y: kind == .blink && !reduceMotion && blink < 0.22 ? 0.08 : 1)
                .rotationEffect(.degrees(kind == .posture ? movement * 3 : 0))
                .offset(y: kind == .posture ? movement * 2 : 0)
        }.accessibilityHidden(true)
    }
}
