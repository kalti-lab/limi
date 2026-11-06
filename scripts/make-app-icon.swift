// Draws the AgentBar app icon: three stacked usage bars of different colors
// and lengths on a macOS-style rounded square. Writes a 1024px PNG; --free adds
// the free edition's FREE ribbon. scripts/make-app-icons.sh turns it into .icns.
//   swift scripts/make-app-icon.swift <output.png> [--free]
import AppKit

let arguments = CommandLine.arguments.dropFirst()
let output = arguments.first { !$0.hasPrefix("--") } ?? "AppIcon-1024.png"
let free = arguments.contains("--free")
let size: CGFloat = 1024
// macOS icon grid: an 824pt body centered on the 1024pt canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 185

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Body with a soft drop shadow and a light top-to-bottom gradient.
let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
color(0xF4F6FA).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0xFFFFFF), ending: color(0xE3E7EF))!.draw(in: shape, angle: -90)
NSColor.black.withAlphaComponent(0.08).setStroke()
shape.lineWidth = 2
shape.stroke()

// Three usage bars: a faint full-length track with a colored fill of a different length.
let bars: [(fill: CGFloat, top: UInt32, bottom: UInt32)] = [
    (0.82, 0x5AA9FF, 0x1F6FEB), // blue
    (0.56, 0xB18CFF, 0x7A4DE8), // purple
    (0.34, 0x5EE3A1, 0x1DB46E), // green
]
let barHeight: CGFloat = 104
let gap: CGFloat = 74
let left = body.minX + 150
let trackWidth = body.width - 300
let stack = barHeight * CGFloat(bars.count) + gap * CGFloat(bars.count - 1)
var y = body.midY + stack / 2 - barHeight
for bar in bars {
    let track = NSBezierPath(roundedRect: NSRect(x: left, y: y, width: trackWidth, height: barHeight),
                             xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSColor.black.withAlphaComponent(0.07).setFill()
    track.fill()
    let fillRect = NSRect(x: left, y: y, width: trackWidth * bar.fill, height: barHeight)
    let fill = NSBezierPath(roundedRect: fillRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSGradient(starting: color(bar.top), ending: color(bar.bottom))!.draw(in: fill, angle: -90)
    // A thin highlight along the top edge gives the bars some depth.
    NSGraphicsContext.saveGraphicsState()
    fill.addClip()
    NSColor.white.withAlphaComponent(0.25).setFill()
    NSRect(x: fillRect.minX, y: fillRect.maxY - barHeight * 0.32, width: fillRect.width, height: barHeight * 0.32).fill()
    NSGraphicsContext.restoreGraphicsState()
    y -= barHeight + gap
}

// The free edition wears a FREE ribbon across the top-right corner, clear of
// the bars, so it reads as the free one at a glance.
if free {
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    let turn = NSAffineTransform()
    turn.translateX(by: body.maxX - 150, yBy: body.maxY - 150)
    turn.rotate(byDegrees: -45)
    turn.concat()
    let band = NSRect(x: -460, y: -66, width: 920, height: 132)
    NSGraphicsContext.saveGraphicsState()
    let ribbonShadow = NSShadow()
    ribbonShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    ribbonShadow.shadowOffset = NSSize(width: 0, height: -6)
    ribbonShadow.shadowBlurRadius = 14
    ribbonShadow.set()
    color(0xF05A28).setFill()
    NSBezierPath(rect: band).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0xFF9A4D), ending: color(0xEE5524))!.draw(in: band, angle: -90)
    let heavy = NSFont.systemFont(ofSize: 82, weight: .heavy)
    let font = heavy.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 82) } ?? heavy
    let label = NSAttributedString(string: "FREE", attributes: [.font: font, .foregroundColor: NSColor.white, .kern: 10])
    // Center the capitals, not the line box, on the band.
    label.draw(at: NSPoint(x: -label.size().width / 2 + 5, y: -font.capHeight / 2 + font.descender))
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
