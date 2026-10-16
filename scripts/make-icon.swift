import Cocoa
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let outer = NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 215, yRadius: 215)
NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.14, blue: 0.34, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.14, alpha: 1))!.draw(in: outer, angle: -70)
for (rect, alpha) in [(NSRect(x: 130, y: 310, width: 300, height: 390), 0.35), (NSRect(x: 610, y: 310, width: 280, height: 390), 0.35), (NSRect(x: 310, y: 240, width: 405, height: 535), 1.0)] {
    let path = NSBezierPath(roundedRect: rect, xRadius: 38, yRadius: 38)
    NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.29, alpha: 1).setFill(); path.fill()
    NSColor(calibratedRed: 0.68, green: 0.54, blue: 1, alpha: alpha).setStroke(); path.lineWidth = alpha == 1 ? 13 : 8; path.stroke()
    let header = NSBezierPath(); header.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 72)); header.line(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 72))
    NSColor.white.withAlphaComponent(0.12).setStroke(); header.lineWidth = 5; header.stroke()
}
let button = NSBezierPath(ovalIn: NSRect(x: 255, y: 710, width: 120, height: 120))
NSColor(calibratedRed: 0.69, green: 0.55, blue: 1, alpha: 1).setFill(); button.fill()
let cross = NSBezierPath(); cross.move(to: CGPoint(x: 294, y: 749)); cross.line(to: CGPoint(x: 336, y: 791)); cross.move(to: CGPoint(x: 294, y: 791)); cross.line(to: CGPoint(x: 336, y: 749))
NSColor.white.setStroke(); cross.lineWidth = 10; cross.lineCapStyle = .round; cross.stroke()
image.unlockFocus()
let directory = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels)); NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
