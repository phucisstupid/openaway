import SwiftUI
import OpenAwayCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    static let pages: [(id: String, title: String, symbol: String, color: Color)] = [
        ("overview", "Overview", "square.grid.2x2.fill", .blue),
        ("general", "General", "gearshape.fill", .purple),
        ("insights", "Activity", "chart.bar.fill", .blue),
        ("about", "About", "info", .yellow)
    ]
    var body: some View {
        Group {
            if model.selectedPage == "general" {
                ScheduleView(model: model)
            } else {
                ScrollView {
                    Group {
                        switch model.selectedPage {
                        case "insights": InsightsView(model: model)
                        case "about": AboutView(model: model)
                        default: overview
                        }
                    }
                    .frame(maxWidth: 800)
                    .padding(26).frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollIndicators(.hidden)
            }
        }
        .id(model.selectedPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(model.settings.appearance == "dark" ? .dark : model.settings.appearance == "light" ? .light : nil)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A little room to breathe.").font(.largeTitle.bold())
                    Text("Your next break is taken care of.").foregroundStyle(.secondary)
                }
                Spacer()
                Label(model.engine.phase == .paused ? "Paused" : "Active", systemImage: model.engine.phase == .paused ? "pause.circle.fill" : "checkmark.circle.fill")
                    .font(.callout).padding(.horizontal, 14).padding(.vertical, 9).nativeGlass(cornerRadius: 30)
            }
            ZStack {
                if model.settings.breakTheme == "blur" {
                    DesktopBlurView()
                } else {
                    LandscapeView(theme: model.settings.breakTheme)
                }
                VStack(spacing: 12) {
                    Text(model.engine.phase == .resting ? "Time to rest" : model.engine.phase == .paused ? "Reminders paused" : "Next break")
                        .font(.headline)
                    Text(timeString(model.engine.remainingSeconds))
                        .font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit()
                    Text(statusText).font(.callout).multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button { model.startBreak() } label: {
                            Label(model.engine.phase == .resting ? "Show break" : "Take a break", systemImage: "leaf")
                        }.buttonStyle(PrimaryButtonStyle())
                        if model.engine.phase == .focusing || model.engine.phase == .preparing {
                            Button("+5 minutes") { model.snooze(minutes: 5) }
                                .buttonStyle(SecondaryButtonStyle()).help("Delay your next break by five minutes")
                        }
                    }.controlSize(.large).padding(.top, 8)
                }.foregroundStyle(model.settings.breakTheme == "blur" ? Color.primary : Color(hex: 0x20382B)).padding(32)
            }.frame(height: 330).clipShape(RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 16) {
                metric("Completed today", value: "\(model.completedToday)", symbol: "checkmark.circle")
                metric("Rest today", value: "\(model.restedTodaySeconds / 60)m \(model.restedTodaySeconds % 60)s", symbol: "hourglass")
                metric("Daily streak", value: "\(model.streakDays) days", symbol: "flame")
            }
            GroupBox("Your routine") {
                VStack(spacing: 12) {
                    LabeledContent("Eye break", value: "\(model.settings.breakDurationSeconds) seconds every \(model.settings.breakIntervalMinutes) minutes")
                    Divider()
                    LabeledContent("Long break", value: model.settings.longBreakEnabled ? "\(model.settings.longBreakDurationMinutes) minutes after \(model.settings.longBreakEvery) eye breaks" : "Off")
                    Divider()
                    HStack {
                        Label("Automatic pauses", systemImage: "pause.circle")
                        Spacer()
                        Text(automaticPauseSummary).foregroundStyle(.secondary)
                    }
                    HStack {
                        Spacer()
                        Button("Edit routine…") { model.selectedPage = "general" }
                    }
                }.padding(10)
            }
        }
    }

    private var statusText: String {
        if model.engine.phase == .paused { return model.engine.pauseReason ?? "Resume when you’re ready." }
        if model.engine.phase == .resting { return "Let your eyes find something in the distance." }
        if model.engine.phase == .preparing {
            return model.engine.remainingSeconds == 0 ? "Waiting for a pause in your work." : "Almost time. Find a comfortable stopping point."
        }
        return model.engine.currentBreakKind == .long ? "A longer pause to get up and move." : "Settle into your work. We’ll remind you."
    }
    private var automaticPauseSummary: String {
        var items: [String] = []
        if model.settings.pauseForMeetings { items.append("Meetings") }
        if model.settings.pauseForVideo { items.append("Video") }
        if model.settings.idlePauseEnabled { items.append("Idle") }
        return items.isEmpty ? "Sleep and lock" : items.joined(separator: " · ")
    }
    private func metric(_ title: String, value: String, symbol: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
                Text(value).font(.system(.title, design: .rounded)).fontWeight(.medium)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
    }
}

struct DashboardSidebarView: View {
    @ObservedObject var model: AppModel
    private var pages: [(id: String, title: String, symbol: String, color: Color)] { DashboardView.pages }

    var body: some View {
        List(selection: $model.selectedPage) {
            sidebarPages(0..<pages.count)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func sidebarPages(_ range: Range<Int>) -> some View {
        ForEach(range, id: \.self) { index in
            let page = pages[index]
            Label {
                Text(page.title).lineLimit(1)
            } icon: {
                SettingsIcon(symbol: page.symbol, color: page.color, size: 26)
            }
            .tag(page.id)
            .help(page.title)
        }
    }
}
