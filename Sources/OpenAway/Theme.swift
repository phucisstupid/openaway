import SwiftUI
import AppKit

// SDK 27 also exports a State macro. A type alias explicitly selects the
// backwards-compatible property wrapper on Command Line Tools without plugins.
typealias ViewState<Value> = SwiftUI.State<Value>

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

enum Palette {
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let background = Color(nsColor: .windowBackgroundColor)
    static let line = Color(nsColor: .separatorColor)
    static let accent = Color.accentColor
    static let soft = Color.accentColor.opacity(0.12)
}

extension View {
    @ViewBuilder
    func nativeGlass(cornerRadius: CGFloat = 20) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        GroupBox {
            content.padding(max(0, padding - 10)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PrimaryButtonStyle: PrimitiveButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Button(configuration).buttonStyle(.glassProminent)
        } else {
            Button(configuration).buttonStyle(.borderedProminent)
        }
        #else
        Button(configuration).buttonStyle(.borderedProminent)
        #endif
    }
}

struct SecondaryButtonStyle: PrimitiveButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Button(configuration).buttonStyle(.glass)
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
        #else
        Button(configuration).buttonStyle(.bordered)
        #endif
    }
}

struct SectionLabel: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
            if let detail { Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary) }
        }
    }
}

struct NumberPreference: View {
    let title: String
    var detail: String = ""
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = "min"
    var step: Int = 1
    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, value: $value, formatter: Self.formatter)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                    .accessibilityLabel("\(title), \(unit)")
                    .onSubmit { value = min(range.upperBound, max(range.lowerBound, value)) }
                Text(unit).foregroundStyle(.secondary)
                    .fixedSize().frame(width: 80, alignment: .leading)
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                    .accessibilityLabel("\(title), \(unit)")
            }
            .fixedSize(horizontal: true, vertical: false)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }
    private static var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        return formatter
    }
}

func timeString(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return String(format: "%02d:%02d", safe / 60, safe % 60)
}

struct BreakBackgroundView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let radius = CGFloat(model.settings.breakImageBlurRadius)
        Group {
            if model.settings.breakTheme == "blurImage", let image = model.breakImage {
                GeometryReader { geometry in
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width + radius * 3, height: geometry.size.height + radius * 3)
                        .blur(radius: radius, opaque: true)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }.clipped()
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                }
            } else {
                DesktopBlurView()
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DesktopBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
