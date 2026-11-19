import AppKit
let image = NSImage(size: NSSize(width: 600, height: 360))
image.lockFocus()
NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.90, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 600, height: 360).fill()
let heading: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.23, alpha: 1)]
let detail: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor(calibratedRed: 0.28, green: 0.31, blue: 0.29, alpha: 1)]
("Install DoorSound" as NSString).draw(at: NSPoint(x: 214, y: 304), withAttributes: heading)
("Drag DoorSound to Applications" as NSString).draw(at: NSPoint(x: 205, y: 45), withAttributes: detail)
let arrow = NSBezierPath(); arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 265, y: 190)); arrow.line(to: NSPoint(x: 335, y: 190)); arrow.move(to: NSPoint(x: 325, y: 200)); arrow.line(to: NSPoint(x: 335, y: 190)); arrow.line(to: NSPoint(x: 325, y: 180))
NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.48, alpha: 1).setStroke(); arrow.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
