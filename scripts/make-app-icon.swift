// Draws the app icon: one six-pointed star, after one half of the Are.na mark.
// Keep the geometry in sync with Chirp/Shared/ArenaStar.swift.
//
//   xcrun swift scripts/make-app-icon.swift Chirp/Resources/Assets.xcassets/AppIcon.appiconset

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

/// Six tapered rays every 60°, pointing up and down. `radius` is the tip
/// radius; valleys between rays sit at 36% of it, as in the Are.na mark.
func starPath(center: CGPoint, radius: CGFloat) -> CGPath {
    let valley = radius * 0.36
    let tipWidth = radius * 0.03
    let path = CGMutablePath()
    for ray in 0..<6 {
        let angle = (-90 + Double(ray) * 60) * .pi / 180
        let tip = CGPoint(x: center.x + (radius - tipWidth) * cos(angle), y: center.y + (radius - tipWidth) * sin(angle))
        let before = angle - .pi / 6
        let valleyBefore = CGPoint(x: center.x + valley * cos(before), y: center.y + valley * sin(before))
        if ray == 0 {
            path.move(to: valleyBefore)
        } else {
            path.addLine(to: valleyBefore)
        }
        path.addLine(to: CGPoint(x: tip.x + tipWidth * sin(angle), y: tip.y - tipWidth * cos(angle)))
        path.addArc(center: tip, radius: tipWidth, startAngle: angle - .pi / 2, endAngle: angle + .pi / 2, clockwise: false)
    }
    path.closeSubpath()
    return path
}

func writeIcon(named name: String, background: CGColor?, star: CGColor) throws {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Flip so y grows downward, matching SwiftUI.
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    if let background {
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    context.setFillColor(star)
    context.addPath(starPath(center: CGPoint(x: size / 2, y: size / 2), radius: CGFloat(size) * 0.31))
    context.fillPath()

    let url = outputDirectory.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    print("wrote \(url.path)")
}

let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
// The light icon has no transparency; the dark one lets the system background show.
try writeIcon(named: "AppIcon.png", background: white, star: black)
try writeIcon(named: "AppIcon-Dark.png", background: nil, star: white)
try writeIcon(named: "AppIcon-Tinted.png", background: black, star: white)
