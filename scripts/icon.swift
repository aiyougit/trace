import AppKit
let output = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let image = NSImage(size: NSSize(width: px, height: px))
        image.lockFocus()
        let s = CGFloat(px)
        NSColor(srgbRed: 0.062, green: 0.086, blue: 0.098, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88), xRadius: s * 0.20, yRadius: s * 0.20).fill()
        NSColor(srgbRed: 0.616, green: 0.910, blue: 0.8, alpha: 1).setFill()
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x:s*0.31,y:s*0.76)); arrow.line(to:NSPoint(x:s*0.32,y:s*0.27))
        arrow.line(to:NSPoint(x:s*0.45,y:s*0.4)); arrow.line(to:NSPoint(x:s*0.56,y:s*0.20))
        arrow.line(to:NSPoint(x:s*0.65,y:s*0.25)); arrow.line(to:NSPoint(x:s*0.54,y:s*0.45))
        arrow.line(to:NSPoint(x:s*0.73,y:s*0.46)); arrow.close(); arrow.fill()
        NSColor(srgbRed: 0.616, green: 0.910, blue: 0.8, alpha: 0.5).setStroke()
        let trail = NSBezierPath(); trail.lineWidth = s*0.025; trail.lineCapStyle = .round
        trail.move(to:NSPoint(x:s*0.49,y:s*0.75)); trail.line(to:NSPoint(x:s*0.74,y:s*0.65)); trail.stroke()
        let trail2 = NSBezierPath(); trail2.lineWidth=s*0.025; trail2.lineCapStyle = .round
        trail2.move(to:NSPoint(x:s*0.56,y:s*0.84)); trail2.line(to:NSPoint(x:s*0.78,y:s*0.75)); trail2.stroke()
        image.unlockFocus()
        let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output + "/AppIcon.icns"]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: iconset)
