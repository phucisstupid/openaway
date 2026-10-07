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
        let recent = Array(model.records.sorted { $0.date > $1.date }.prefix(8))
        Form {
            Section {
                LabeledContent("Completed today", value: "\(model.completedToday)")
                    .accessibilityElement(children: .combine)
                LabeledContent("Rest today", value: restLabel)
                    .accessibilityElement(children: .combine)
                LabeledContent("Current streak", value: "\(model.streakDays) \(model.streakDays == 1 ? "day" : "days")")
                    .accessibilityElement(children: .combine)
            } header: {
                Text("Summary")
            } footer: {
                Text("Only completed breaks count toward totals and your streak.")
            }

            Section("Last 7 days") {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Completed breaks", value: "\(weekly) total")
                    Chart(days, id: \.self) { day in
                        BarMark(x: .value("Day", day, unit: .day), y: .value("Breaks", count(day)))
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.accentColor.opacity(0.4))
                            .cornerRadius(3)
                    }
                    .chartYScale(domain: 0...maximum)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: Array(stride(from: 0, through: maximum, by: max(1, (maximum + 3) / 4))))
                    }
                    .frame(height: 160)
                    .accessibilityLabel("Completed breaks over the last seven days")
                    if weekly == 0 {
                        Text("Completed breaks will appear here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                if recent.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No breaks yet")
                            Text("Take a break to start your history.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Take an eye break") { model.startBreak() }
                    }
                } else {
                    ForEach(recent) { record in
                        HStack(spacing: 12) {
                            Image(systemName: record.kind == .long ? "figure.walk" : "eye")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.kind == .long ? "Long break" : "Eye break")
                                Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(timeString(record.durationSeconds))
                                .monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .trailing)
                            Text(record.completed ? "Completed" : "Ended early")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(width: 88, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Recent breaks")
            } footer: {
                Text("Break history is stored only on this Mac.")
            }

            Section {
                Button("Clear History…") { showingClear = true }
                    .disabled(model.records.isEmpty)
            } footer: {
                Text("Clearing history also resets your statistics.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .buttonStyle(.bordered)
        .alert("Clear all break history?", isPresented: $showingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { model.clearHistory() }
        } message: {
            Text("This permanently removes your activity and resets your statistics. This cannot be undone.")
        }
    }

    private var restLabel: String {
        if model.restedTodaySeconds < 60 { return "\(model.restedTodaySeconds) sec" }
        return "\(model.restedTodaySeconds / 60)m \(model.restedTodaySeconds % 60)s"
    }
}
