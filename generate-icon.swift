#!/usr/bin/env swift
import AppKit

// Render the "macbook.slash" SF Symbol into an .icns file for the app icon.
// Uses iconutil under the hood, which requires a .iconset folder with
// PNGs at specific sizes.

let iconsetPath = "AppIcon.iconset"
let icnsPath = "AppIcon.icns"

// Required sizes for a macOS .iconset
let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

// Create iconset directory
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for entry in sizes {
    let pixelSize = entry.size
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()

    // Background: rounded rect with gradient (dark gray)
    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = pixelSize * 0.22 // macOS icon corner radius
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient background
    let gradient = NSGradient(starting: NSColor(white: 0.18, alpha: 1.0),
                               ending: NSColor(white: 0.08, alpha: 1.0))!
    gradient.draw(in: path, angle: 270)

    // Draw the SF Symbol centered in terminal green
    let accentBlue = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)

    if let symbol = NSImage(systemSymbolName: "macbook.slash", accessibilityDescription: nil) {
        // Apply both size and color configuration
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: pixelSize * 0.45, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [accentBlue])
        let combined = sizeConfig.applying(colorConfig)
        let configured = symbol.withSymbolConfiguration(combined)!

        let symbolSize = configured.size
        let x = (pixelSize - symbolSize.width) / 2
        let y = (pixelSize - symbolSize.height) / 2

        configured.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                        from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()

    // Save as PNG
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(entry.name)")
        continue
    }

    let filePath = "\(iconsetPath)/\(entry.name).png"
    try! pngData.write(to: URL(fileURLWithPath: filePath))
    print("Generated \(entry.name) (\(Int(pixelSize))px)")
}

// Convert iconset to icns using iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("\nCreated \(icnsPath)")
    // Clean up iconset folder
    try? FileManager.default.removeItem(atPath: iconsetPath)
} else {
    print("iconutil failed with status \(process.terminationStatus)")
}
