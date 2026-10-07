import SwiftUI

struct ExperienceView: View {
    @ObservedObject var model: AppModel
    @ViewState private var messageDraft = ""
    @FocusState private var messageFocused: Bool

    var body: some View {
        Group {
            Picker("Background", selection: $model.settings.breakTheme) {
                Text("Blur Desktop").tag("blur")
                Text("Image").tag("blurImage")
            }.pickerStyle(.segmented)
            if model.settings.breakTheme == "blurImage" {
                HStack(spacing: 16) {
                    if let image = model.breakImage {
                        Image(nsImage: image).resizable().scaledToFill()
                            .blur(radius: model.settings.breakImageBlurRadius / 8)
                            .frame(width: 128, height: 72).clipped().cornerRadius(6)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.breakImage == nil
                             ? (model.settings.breakImagePath == nil ? "No picture selected" : "Picture unavailable")
                             : model.settings.breakImageName ?? "Your picture")
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button { model.chooseBreakImage() } label: {
                            Label(model.breakImage == nil ? "Choose picture…" : "Change picture…", systemImage: "photo.badge.plus")
                        }
                    }
                    Spacer()
                    if model.settings.breakImagePath != nil {
                        Button { model.removeBreakImage() } label: { Image(systemName: "xmark.circle") }
                            .help("Remove picture").accessibilityLabel("Remove picture")
                    }
                }
                if model.breakImage == nil {
                    Text("Desktop blur is used until you choose another picture.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = model.breakImageError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent("Blur") {
                    HStack {
                        Text("None").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $model.settings.breakImageBlurRadius, in: 0...80)
                            .accessibilityLabel("Image blur")
                        Text("Strong").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(model.breakImage == nil)
            }
            TextField("Break message", text: $messageDraft)
                .textFieldStyle(.roundedBorder).focused($messageFocused)
                .onSubmit { saveMessage() }
                .onChange(of: messageFocused) { focused in if !focused { saveMessage() } }
            HStack {
                Spacer()
                Button { saveMessage(); model.previewBreak() } label: {
                    Label("Preview break", systemImage: "play")
                }
            }
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
