// Render an SVG into a transparent template PNG (AppKit/NSImage).
// Usage: svg2png <input.svg> <output.png> <maxSizePx>
// Unlike `qlmanage -t`, this preserves a transparent background (qlmanage
// flattens thumbnails onto opaque white, which makes template images render as
// solid tinted squares). Used by generate-ios12-icons.py.
import AppKit

let a = CommandLine.arguments
guard a.count == 4, let img = NSImage(contentsOfFile: a[1]), let size = Double(a[3]) else {
    FileHandle.standardError.write("svg2png: bad args or load failed\n".data(using: .utf8)!)
    exit(1)
}
let w = img.size.width, h = img.size.height
let scale = size / max(w, h)
let pw = max(1, Int((w * scale).rounded())), ph = max(1, Int((h * scale).rounded()))
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(2) }
rep.size = NSSize(width: pw, height: ph)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.set()
NSRect(x: 0, y: 0, width: pw, height: ph).fill()
img.draw(in: NSRect(x: 0, y: 0, width: pw, height: ph),
         from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(3) }
try! png.write(to: URL(fileURLWithPath: a[2]))
