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
        NSGradient(starting: NSColor(srgbRed: 0.43, green: 0.60, blue: 0.40, alpha: 1), ending: NSColor(srgbRed: 0.19, green: 0.35, blue: 0.26, alpha: 1))!.draw(in: base, angle: -70)
        base.addClip()
        NSColor(srgbRed: 0.88, green: 0.94, blue: 0.80, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: NSRect(x: 570, y: 590, width: 440, height: 440)).fill()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 306, y: 324))
        leaf.curve(to: NSPoint(x: 753, y: 752), controlPoint1: NSPoint(x: 233, y: 603), controlPoint2: NSPoint(x: 574, y: 552))
        leaf.curve(to: NSPoint(x: 306, y: 324), controlPoint1: NSPoint(x: 829, y: 382), controlPoint2: NSPoint(x: 522, y: 219))
        NSColor(srgbRed: 0.93, green: 0.96, blue: 0.86, alpha: 1).setFill()
        leaf.fill()
        let vein = NSBezierPath()
        vein.move(to: NSPoint(x: 255, y: 263))
        vein.curve(to: NSPoint(x: 648, y: 599), controlPoint1: NSPoint(x: 394, y: 346), controlPoint2: NSPoint(x: 456, y: 493))
        vein.lineWidth = 27
        vein.lineCapStyle = .round
        NSColor(srgbRed: 0.27, green: 0.44, blue: 0.31, alpha: 1).setStroke()
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
