import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    static let pages: [(id: String, title: String, symbol: String)] = [
        ("general", "General", "gearshape"),
        ("wellness", "Wellness Reminders", "heart"),
        ("appearance", "Appearance", "circle.lefthalf.filled"),
        ("shortcuts", "Keyboard Shortcuts", "keyboard"),
        ("insights", "Activity", "chart.bar"),
        ("about", "About", "info.circle"),
    ]
    var body: some View {
        Group {
            switch model.selectedPage {
            case "wellness": WellnessView(model: model)
            case "appearance": AppearanceView(model: model)
            case "shortcuts": KeyboardShortcutsView()
            case "about": AboutView()
            case "insights": InsightsView(model: model)
            default: ScheduleView(model: model)
            }
        }
        .id(model.selectedPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(
            model.settings.appearance == "dark" ? .dark : model.settings.appearance == "light" ? .light : nil)
    }

}

struct DashboardSidebarView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        List(selection: $model.selectedPage) {
            ForEach(DashboardView.pages, id: \.id) { page in
                Label(page.title, systemImage: page.symbol)
                    .lineLimit(1)
                    .tag(page.id)
                    .help(page.title)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

}
