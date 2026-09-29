import SwiftUI

struct AboutView: View {
    @ObservedObject var model: AppModel
    @ViewState private var showingClear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading("A little care. Open to everyone.", subtitle: "A free, independent break reminder, made for your Mac.")
            Card(padding: 32) {
                HStack(alignment: .top, spacing: 25) {
                    AwayMark(size: 78)
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("OpenAway").font(.system(size: 31, weight: .semibold, design: .rounded)).tracking(-1)
                            Text("0.4.6").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                        Text("Your screen can wait a moment.").font(.system(size: 20, weight: .medium, design: .default))
                        Text("OpenAway helps you make space for regular eye breaks, longer pauses, and small moments to check in with yourself. A quiet companion for the time you spend at your desk.")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                valueCard("Open by nature", icon: "curlybraces", text: "Released under the MIT license. Read the code, make it your own, and share what you build.")
                valueCard("Private by default", icon: "lock.shield", text: "No account. No analytics. No network requests. Your settings and break history stay on this Mac.")
                valueCard("Made for the Mac", icon: "desktopcomputer", text: "Native SwiftUI and AppKit. A lightweight menu bar companion with no third-party dependencies.")
            }
            Card {
                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(title: "A few handy shortcuts", detail: "Available while OpenAway is the active app.")
                    shortcut("Take an eye break", keys: "⇧ ⌘ B")
                    shortcut("Pause or resume reminders", keys: "⇧ ⌘ P")
                    shortcut("Skip a break (twice within 2 seconds)", keys: "esc esc")
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(title: "Activity history", detail: "Manage the break records stored on this Mac.")
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Clear your activity").font(.system(size: 12, weight: .medium))
                            Text("Permanently remove all saved break records.").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Button("Clear history") { showingClear = true }.buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            Text("Inspired by the idea of mindful screen breaks and LookAway. OpenAway is an independent project and is not affiliated with or endorsed by LookAway or Mystical Bits. All artwork and interface code are original.")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .alert("Clear all break history?", isPresented: $showingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { model.clearHistory() }
        } message: { Text("This permanently removes your activity and resets your statistics. This cannot be undone.") }
    }
    private func valueCard(_ title: String, icon: String, text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(Palette.accent)
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(text).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }.frame(maxHeight: .infinity, alignment: .top)
        }
    }
    private func shortcut(_ title: String, keys: String) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            Text(keys).font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 11).padding(.vertical, 6).background(Palette.background, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
