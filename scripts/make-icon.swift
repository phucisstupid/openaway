import AppKit
import Foundation

// Original vector icon, rendered locally at each macOS icon size.
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 212, yRadius: 212)
        NSGradient(starting: NSColor(srgbRed: 0.07, green: 0.065, blue: 0.06, alpha: 1), ending: NSColor(srgbRed: 0.60, green: 0.46, blue: 0.25, alpha: 1))!.draw(in: base, angle: 45)
        let face = NSBezierPath(roundedRect: NSRect(x: 63, y: 63, width: 898, height: 898), xRadius: 207, yRadius: 207)
        NSGradient(starting: NSColor(srgbRed: 0.015, green: 0.015, blue: 0.015, alpha: 1), ending: NSColor(srgbRed: 0.18, green: 0.17, blue: 0.15, alpha: 1))!.draw(in: face, angle: 45)
        base.addClip()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 306, y: 324))
        leaf.curve(to: NSPoint(x: 753, y: 752), controlPoint1: NSPoint(x: 233, y: 603), controlPoint2: NSPoint(x: 574, y: 552))
        leaf.curve(to: NSPoint(x: 306, y: 324), controlPoint1: NSPoint(x: 829, y: 382), controlPoint2: NSPoint(x: 522, y: 219))
        NSGradient(colorsAndLocations:
            (NSColor(srgbRed: 0.91, green: 0.28, blue: 0.85, alpha: 1), 0),
            (NSColor(srgbRed: 1, green: 0.39, blue: 0.67, alpha: 1), 0.52),
            (NSColor(srgbRed: 1, green: 0.83, blue: 0.47, alpha: 1), 1))!.draw(in: leaf, angle: 35)
        let vein = NSBezierPath()
        vein.move(to: NSPoint(x: 255, y: 263))
        vein.curve(to: NSPoint(x: 648, y: 599), controlPoint1: NSPoint(x: 394, y: 346), controlPoint2: NSPoint(x: 456, y: 493))
        vein.lineWidth = 27
        vein.lineCapStyle = .round
        NSColor(srgbRed: 0.09, green: 0.07, blue: 0.09, alpha: 1).setStroke()
        vein.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: output).appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}

// An ICNS file is a sized container of PNG representations. Writing it directly
// keeps icon regeneration independent of iconutil versions and tool selection.
let representations = [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
]
func lengthData(_ count: Int) -> Data {
    var value = UInt32(count).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var entries = Data()
for (type, filename) in representations {
    let png = try Data(contentsOf: URL(fileURLWithPath: output).appendingPathComponent(filename))
    entries.append(contentsOf: type.utf8)
    entries.append(lengthData(png.count + 8))
    entries.append(png)
}
var icon = Data("icns".utf8)
icon.append(lengthData(entries.count + 8))
icon.append(entries)
let iconURL = URL(fileURLWithPath: output).deletingPathExtension().appendingPathExtension("icns")
try icon.write(to: iconURL)
print("Created \(iconURL.path)")
