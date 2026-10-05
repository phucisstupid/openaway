import SwiftUI

struct AppearanceView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Application") {
                Picker("Mode", selection: $model.settings.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }.pickerStyle(.segmented)
            }
            Section("Break screen") {
                ExperienceView(model: model)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
