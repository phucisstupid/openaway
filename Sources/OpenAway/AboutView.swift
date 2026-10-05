import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("OpenAway").font(.title2.weight(.semibold))
                Text(version).font(.caption).foregroundStyle(.secondary)
            }

            Text("A break reminder for macOS.")
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://github.com/phucisstupid/openaway")!) {
                Label("phucisstupid/openaway", systemImage: "arrow.up.right.square")
            }
            .help("View OpenAway on GitHub")
            .padding(.top, 8)

            Text("MIT License. Independent project.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var version: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "Development build"
        }
        return "Version \(version)"
    }
}
