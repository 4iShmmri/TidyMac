// TidyMac — by M.Alshmmari
//
// Turns Resources/IconSource.png (the artwork, full-bleed square) into:
//   Resources/AppIcon.icns          the app icon, on the standard macOS rounded tile
//   Resources/MenuBarIcon.png/@2x   a black-on-clear template for the menu bar
// Run from the project folder:  swift scripts/make-icon.swift

import AppKit

let source = NSImage(contentsOfFile: "Resources/IconSource.png")!

// MARK: - App icon

func appIcon() -> NSImage {
    let size: CGFloat = 1024
    return NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let inset: CGFloat = 100 // macOS icons leave a margin around the tile
        let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        source.draw(in: tile)
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
}

// MARK: - Menu bar template

/// The artwork's white shapes, cut out as solid black on a clear background and
/// cropped tight. macOS recolours template images to fit the menu bar.
func menuBarShape() -> CGImage {
    let art = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let width = art.width, height = art.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let space = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue

    let input = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                          bytesPerRow: width * 4, space: space, bitmapInfo: info)!
    input.draw(art, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Background is dark teal, shapes are white: brightness becomes opacity, colour becomes black.
    var minX = width, minY = height, maxX = 0, maxY = 0
    for y in 0..<height {
        for x in 0..<width {
            let i = (y * width + x) * 4
            let brightness = Double(max(pixels[i], pixels[i + 1], pixels[i + 2])) / 255
            let alpha = max(0, min(1, (brightness - 0.35) / 0.5))
            pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0
            pixels[i + 3] = UInt8(alpha * 255)
            if alpha > 0.5 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }

    let output = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                           bytesPerRow: width * 4, space: space, bitmapInfo: info)!
    let side = max(maxX - minX, maxY - minY) + 1
    let crop = CGRect(x: (minX + maxX - side) / 2, y: (minY + maxY - side) / 2, width: side, height: side)
    return output.makeImage()!.cropping(to: crop)!
}

// MARK: - Writing files

func writePNG(_ draw: (NSRect) -> Void, pixels: Int, to path: String) {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    draw(NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let icon = appIcon()
let iconset = "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    writePNG({ icon.draw(in: $0) }, pixels: points, to: "\(iconset)/icon_\(points)x\(points).png")
    writePNG({ icon.draw(in: $0) }, pixels: points * 2, to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}
writePNG({ icon.draw(in: $0) }, pixels: 1024, to: "build/AppIcon-preview.png")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()

let shape = NSImage(cgImage: menuBarShape(), size: .zero)
writePNG({ shape.draw(in: $0) }, pixels: 18, to: "Resources/MenuBarIcon.png")
writePNG({ shape.draw(in: $0) }, pixels: 36, to: "Resources/MenuBarIcon@2x.png")

print("Wrote Resources/AppIcon.icns and Resources/MenuBarIcon.png")
