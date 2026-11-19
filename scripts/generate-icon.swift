import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let destination = root.appendingPathComponent("Crack/Assets.xcassets/AppIcon.appiconset")
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.23, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 220, yRadius: 220).fill()
    NSColor(calibratedRed: 0.93, green: 0.88, blue: 0.76, alpha: 1).setStroke()
    let frame = NSBezierPath(); frame.lineWidth = 42; frame.lineCapStyle = .round; frame.lineJoinStyle = .round
    frame.move(to: NSPoint(x: 280, y: 235)); frame.line(to: NSPoint(x: 280, y: 750)); frame.line(to: NSPoint(x: 680, y: 750)); frame.line(to: NSPoint(x: 680, y: 235)); frame.stroke()
    let door = NSBezierPath(); door.move(to: NSPoint(x: 316, y: 260)); door.line(to: NSPoint(x: 585, y: 330)); door.line(to: NSPoint(x: 585, y: 790)); door.line(to: NSPoint(x: 316, y: 730)); door.close()
    NSColor(calibratedRed: 0.88, green: 0.57, blue: 0.38, alpha: 1).setFill(); door.fill()
    NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.78, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 505, y: 502, width: 34, height: 34)).fill()
    let base = NSBezierPath(roundedRect: NSRect(x: 204, y: 187, width: 616, height: 45), xRadius: 22, yRadius: 22); base.fill()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size).png"))
}
