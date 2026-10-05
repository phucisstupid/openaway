import SwiftUI

struct KeyboardShortcutsView: View {
    var body: some View {
        Form {
            Section("Keyboard shortcuts") {
                shortcut("Take an eye break", keys: "⇧⌘B")
                shortcut("Pause or resume", keys: "⇧⌘P")
                shortcut("Open settings", keys: "⌘,")
                shortcut("Quit OpenAway", keys: "⌘Q")
                shortcut("Skip break", keys: "Esc, Esc")
                shortcut("Close preview", keys: "Esc")
                Text("Skipping requires two distinct Escape presses within 2 seconds.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func shortcut(_ title: String, keys: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}
