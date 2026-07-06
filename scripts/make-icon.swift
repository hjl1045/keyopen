import AppKit

// Renders KeyOpen's app icon (an indigo squircle with a keyboard whose one
// "open" key is highlighted) to a 1024×1024 PNG at argv[1].
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rrect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// Background squircle with an indigo gradient.
let inset = size * 0.055
let bg = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
ctx.saveGState()
ctx.addPath(rrect(bg, bg.width * 0.2237))
ctx.clip()
let grad = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor(srgbRed: 0.49, green: 0.53, blue: 0.96, alpha: 1).cgColor,
             NSColor(srgbRed: 0.28, green: 0.33, blue: 0.79, alpha: 1).cgColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Keyboard body (white rounded rect).
let kbW = size * 0.60, kbH = size * 0.42
let kbX = (size - kbW) / 2, kbY = (size - kbH) / 2 - size * 0.01
let kb = CGRect(x: kbX, y: kbY, width: kbW, height: kbH)
ctx.setFillColor(NSColor.white.cgColor)
ctx.addPath(rrect(kb, size * 0.055))
ctx.fillPath()

// Key grid; highlight one key in accent orange (the "open slot").
let cols = 5, rows = 3
let pad = size * 0.05
let gap = size * 0.02
let gridW = kbW - 2 * pad, gridH = kbH - 2 * pad
let keyW = (gridW - CGFloat(cols - 1) * gap) / CGFloat(cols)
let keyH = (gridH - CGFloat(rows - 1) * gap) / CGFloat(rows)
let baseColor = NSColor(srgbRed: 0.30, green: 0.35, blue: 0.80, alpha: 1).cgColor
let accent = NSColor(srgbRed: 0.98, green: 0.58, blue: 0.24, alpha: 1).cgColor
for r in 0..<rows {
    for c in 0..<cols {
        let x = kbX + pad + CGFloat(c) * (keyW + gap)
        let y = kbY + pad + CGFloat(r) * (keyH + gap)
        ctx.setFillColor((r == 1 && c == 3) ? accent : baseColor)
        ctx.addPath(rrect(CGRect(x: x, y: y, width: keyW, height: keyH), keyH * 0.26))
        ctx.fillPath()
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("icon: PNG encode failed\n".utf8)); exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
