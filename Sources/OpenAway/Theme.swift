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

struct AwayMark: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31).fill(Palette.accent)
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.53, weight: .medium)).rotationEffect(.degrees(-18))
                .foregroundStyle(Palette.background)
        }.frame(width: size, height: size)
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

struct SettingsIcon: View {
    let symbol: String
    var color: Color = .pink
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                TextField(title, value: $value, formatter: Self.formatter)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .accessibilityLabel("\(title), \(unit)")
                    .onSubmit { value = min(range.upperBound, max(range.lowerBound, value)) }
                Text(unit).foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                    .accessibilityLabel("\(title), \(unit)")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 28)
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

struct LandscapeView: View {
    var theme: String = "grove"
    private var colors: [Color] {
        switch theme {
        case "ocean": return [Color(hex: 0xCCDFDD), Color(hex: 0xBCD5D5), Color(hex: 0x93BEBF), Color(hex: 0x6D9DA3), Color(hex: 0x4B7D8A)]
        case "dusk": return [Color(hex: 0xEEDACA), Color(hex: 0xD4BDC3), Color(hex: 0xB5A3BA), Color(hex: 0x8C86A2), Color(hex: 0x696F88)]
        default: return [Color(hex: 0xE3E9D5), Color(hex: 0xD2DEBD), Color(hex: 0xB4C7A0), Color(hex: 0x8CA980), Color(hex: 0x66896C)]
        }
    }
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.white.opacity(0.42)).frame(width: h * 0.31, height: h * 0.31)
                    .position(x: w * 0.76, y: h * 0.25)
                Circle().fill(Color.white.opacity(0.13)).frame(width: h * 0.44, height: h * 0.44)
                    .position(x: w * 0.76, y: h * 0.25)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.74))
                    path.addCurve(to: CGPoint(x: w, y: h * 0.42), control1: CGPoint(x: w * 0.43, y: h * 0.87), control2: CGPoint(x: w * 0.42, y: h * 0.04))
                    path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.closeSubpath()
                }.fill(colors[2])
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.66))
                    path.addCurve(to: CGPoint(x: w, y: h * 0.78), control1: CGPoint(x: w * 0.34, y: h * 0.38), control2: CGPoint(x: w * 0.66, y: h * 1.13))
                    path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.closeSubpath()
                }.fill(colors[3])
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.95))
                    path.addCurve(to: CGPoint(x: w, y: h * 0.82), control1: CGPoint(x: w * 0.58, y: h * 0.65), control2: CGPoint(x: w * 0.54, y: h * 0.68))
                    path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.closeSubpath()
                }.fill(colors[4])
                // Fine contour lines make the landscape feel drawn, without bundled artwork.
                Path { path in
                    path.move(to: CGPoint(x: w * 0.47, y: h))
                    path.addCurve(to: CGPoint(x: w * 0.94, y: h * 0.60), control1: CGPoint(x: w * 0.80, y: h * 0.64), control2: CGPoint(x: w * 0.68, y: h * 0.83))
                }.stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        }.clipped().accessibilityHidden(true)
    }
}
