import SwiftUI
import Charts
import OpenAwayCore

struct InsightsView: View {
    @ObservedObject var model: AppModel
    @ViewState private var showingClear = false
    private var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date())) } }
    private func count(_ date: Date) -> Int { model.records.filter { $0.completed && Calendar.current.isDate($0.date, inSameDayAs: date) }.count }
    private var weekly: Int { days.reduce(0) { $0 + count($1) } }
    private var maximum: Int { max(4, days.map(count).max() ?? 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading("Small pauses add up.", subtitle: "A little perspective on the time you’ve made for yourself.")
            HStack(spacing: 16) {
                metric("Breaks today", value: "\(model.completedToday)", icon: "leaf", detail: "Completed moments of rest")
                metric("Time to yourself", value: restLabel, icon: "hourglass", detail: "Completed rest today")
                metric("Your consistency", value: "\(model.streakDays) \(model.streakDays == 1 ? "day" : "days")", icon: "sun.max", detail: "Consecutive days with a break")
            }
            Card(padding: 24) {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        SectionLabel(title: "A week of breathing room", detail: "Completed breaks over the last seven days")
                        Spacer()
                        Text("\(weekly) total").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(Palette.soft, in: Capsule())
                    }
                    Chart(days, id: \.self) { day in
                        BarMark(x: .value("Day", day, unit: .day), y: .value("Breaks", count(day)))
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.accentColor.opacity(0.4))
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...maximum)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .frame(height: 180)
                    if weekly == 0 {
                        Text("Your first break is a good place to start. There’s no score to chase.")
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        SectionLabel(title: "Recent moments", detail: "Your latest breaks, kept only on this Mac.")
                        Spacer()
                        Button { showingClear = true } label: {
                            Label("Clear history", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.records.isEmpty)
                    }
                    if model.records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cup.and.saucer").font(.system(size: 29, weight: .ultraLight)).foregroundStyle(Palette.accent)
                            Text("A fresh page.").font(.system(size: 19, weight: .medium, design: .default))
                            Text("Take your first break and it will appear here.").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            Button { model.startBreak() } label: { Text("Make a little time") }.buttonStyle(SecondaryButtonStyle()).padding(.top, 4)
                        }.frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        ForEach(Array(model.records.sorted { $0.date > $1.date }.prefix(8))) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.kind == .long ? "figure.walk" : "eye")
                                    .foregroundStyle(Palette.accent).frame(width: 31, height: 31).background(Palette.soft, in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.kind == .long ? "A longer pause" : "An eye break").font(.system(size: 12, weight: .medium))
                                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                }
                                Spacer()
                                Text(timeString(record.durationSeconds)).font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(Palette.secondary)
                                Text(record.completed ? "Completed" : "Ended early").font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(record.completed ? Palette.accent : Palette.secondary)
                                    .frame(width: 80).padding(.vertical, 6).background(Palette.background, in: Capsule())
                            }
                            if record.id != model.records.sorted(by: { $0.date > $1.date }).prefix(8).last?.id { Divider().overlay(Palette.line) }
                        }
                    }
                }
            }
        }
        .alert("Clear all break history?", isPresented: $showingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { model.clearHistory() }
        } message: { Text("This permanently removes your activity and resets your statistics. This cannot be undone.") }
    }
    private var restLabel: String {
        if model.restedTodaySeconds < 60 { return "\(model.restedTodaySeconds) sec" }
        return "\(model.restedTodaySeconds / 60)m \(model.restedTodaySeconds % 60)s"
    }
    private func metric(_ title: String, value: String, icon: String, detail: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Image(systemName: icon).foregroundStyle(Palette.accent)
                }
                Text(value).font(.system(size: 29, weight: .medium, design: .rounded))
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
    }
}
