// Renders the app icon from the mockup: horizon, dotted arc, half sun and the two bells.
//
//     swift Tools/make_icon.swift HorizonApp/Resources/Assets.xcassets/AppIcon.appiconset/icon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha
        ])!
}

// Core Graphics has its origin at the bottom left.
let horizon: CGFloat = 400
let centre = CGPoint(x: size / 2, y: horizon)

// Sky from night to dusk, then the ground.
let sky = CGGradient(
    colorsSpace: space,
    colors: [color(0x2A2466), color(0x5B3A8C), color(0xB0507A), color(0xFF8A3D)] as CFArray,
    locations: [0, 0.45, 0.8, 1])!
context.saveGState()
context.clip(to: CGRect(x: 0, y: horizon, width: size, height: size - horizon))
context.drawLinearGradient(sky, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: horizon), options: [])
context.restoreGState()

let ground = CGGradient(
    colorsSpace: space, colors: [color(0x7A4A2E), color(0x2A1A16)] as CFArray, locations: [0, 1])!
context.saveGState()
context.clip(to: CGRect(x: 0, y: 0, width: size, height: horizon))
context.drawLinearGradient(ground, start: CGPoint(x: 0, y: horizon), end: .zero, options: [])
context.restoreGState()

// Half sun with a glow.
let glow = CGGradient(
    colorsSpace: space, colors: [color(0xFFD58A, 0.9), color(0xFFB547, 0)] as CFArray, locations: [0, 1])!
context.saveGState()
context.clip(to: CGRect(x: 0, y: horizon, width: size, height: size))
context.drawRadialGradient(glow, startCenter: centre, startRadius: 120, endCenter: centre, endRadius: 300, options: [])
context.setFillColor(color(0xFFD27A))
context.fillEllipse(in: CGRect(x: centre.x - 150, y: centre.y - 150, width: 300, height: 300))
context.restoreGState()

// Dotted arc from the sunrise bell to the sunset bell.
let radius: CGFloat = 330
context.setFillColor(color(0xFFFFFF))
for step in 1..<12 {
    let angle = CGFloat.pi * CGFloat(step) / 12
    let point = CGPoint(x: centre.x - cos(angle) * radius, y: centre.y + sin(angle) * radius * 0.82)
    context.fillEllipse(in: CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30))
}

// Horizon line.
context.setStrokeColor(color(0xFFFFFF))
context.setLineWidth(22)
context.setLineCap(.round)
context.move(to: CGPoint(x: centre.x - radius - 60, y: horizon))
context.addLine(to: CGPoint(x: centre.x + radius + 60, y: horizon))
context.strokePath()

// The two bells: dawn on the left, dusk on the right.
for (x, hex) in [(centre.x - radius, UInt32(0xFFB547)), (centre.x + radius, UInt32(0xFF5E62))] {
    context.setFillColor(color(hex))
    context.fillEllipse(in: CGRect(x: x - 62, y: horizon - 62, width: 124, height: 124))
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
