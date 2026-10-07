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
    var body: some View {
        Group {
            if model.isShowingHeadsUp && !model.isReminderPreview {
                headsUp
            } else {
                ReminderSymbol(kind: model.reminderKind, active: model.reminderText != nil,
                               animationStart: model.reminderStartedAt)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(model.reminderText ?? "Wellness reminder")
                    .accessibilityAddTraits(.isImage)
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
    let animationStart: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || kind == .headsUp)) { context in
            let seconds = max(0, context.date.timeIntervalSince(animationStart))
            let eyelidHeight = reduceMotion ? 9 : max(0, 4 + 5 * cos(seconds * 2 * .pi / 0.4))
            let straighten = reduceMotion ? 1 : (1 - cos(min(seconds / 0.8, 1) * .pi)) / 2
            ZStack {
                Circle().fill(Color(hex: 0x291D38).opacity(0.90))
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFA943), Color(hex: 0xF65BB3), Color(hex: 0xDB54D5)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
                    .padding(14)
                if kind == .blink {
                    Path { path in
                        for (x, direction) in [(CGFloat(12), CGFloat(1)), (CGFloat(68), CGFloat(-1))] {
                            path.move(to: CGPoint(x: x, y: 24 - eyelidHeight))
                            path.addLine(to: CGPoint(x: x + 18 * direction, y: 24))
                            path.addLine(to: CGPoint(x: x, y: 24 + eyelidHeight))
                        }
                    }
                    .stroke(Color(hex: 0x39223F), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .frame(width: 80, height: 48)
                } else if kind == .posture {
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: 36))
                            path.addLine(to: CGPoint(x: 20, y: 62))
                            path.addLine(to: CGPoint(x: 51, y: 62))
                            path.move(to: CGPoint(x: 24, y: 62))
                            path.addLine(to: CGPoint(x: 24, y: 78))
                        }
                        .stroke(Color(hex: 0x39223F).opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        Path { path in
                            path.addEllipse(in: CGRect(x: 43.5 - 16 * straighten, y: 11.5 - 6 * straighten, width: 15, height: 15))
                        }
                        .fill(Color(hex: 0x39223F))
                        Path { path in
                            path.move(to: CGPoint(x: 49 - 16 * straighten, y: 29 - 6 * straighten))
                            path.addCurve(to: CGPoint(x: 34, y: 55),
                                          control1: CGPoint(x: 42 - 10 * straighten, y: 36),
                                          control2: CGPoint(x: 26 + 8 * straighten, y: 45))
                            path.addLine(to: CGPoint(x: 60, y: 55))
                            path.addLine(to: CGPoint(x: 60, y: 78))
                            path.addLine(to: CGPoint(x: 68, y: 78))
                            path.move(to: CGPoint(x: 44 - 10 * straighten, y: 35 - 5 * straighten))
                            path.addLine(to: CGPoint(x: 49 - 5 * straighten, y: 46))
                            path.addLine(to: CGPoint(x: 61, y: 46))
                        }
                        .stroke(Color(hex: 0x39223F), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                    .frame(width: 88, height: 88)
                } else {
                    Image(systemName: "leaf").font(.system(size: 46, weight: .medium))
                        .foregroundStyle(Color(hex: 0x39223F))
                }
            }
            .frame(width: 160, height: 160)
        }
    }
}
