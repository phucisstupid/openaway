import SwiftUI

struct ExperienceView: View {
    @ObservedObject var model: AppModel
    @ViewState private var messageDraft = ""
    @FocusState private var messageFocused: Bool

    var body: some View {
        Group {
            Picker("Background", selection: $model.settings.breakTheme) {
                Text("Blur desktop").tag("blur")
                Text("Quiet grove").tag("grove")
                Text("Slow tide").tag("ocean")
                Text("Evening hush").tag("dusk")
            }.pickerStyle(.menu)
            if model.settings.breakTheme == "blur" {
                Text("Softly blurs your desktop behind the timer.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("Break message", text: $messageDraft)
                .textFieldStyle(.roundedBorder).focused($messageFocused)
                .onSubmit { saveMessage() }
                .onChange(of: messageFocused) { focused in if !focused { saveMessage() } }
            Button("Preview break") { saveMessage(); model.previewBreak() }
            Text("Press Escape twice to skip a break. A preview closes with one Escape.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { messageDraft = model.settings.breakMessage }
        .onDisappear { saveMessage() }
        .onChange(of: model.settings.breakMessage) { value in messageDraft = value }
    }

    private func saveMessage() {
        model.settings.breakMessage = messageDraft
        messageDraft = model.settings.breakMessage
    }
}
