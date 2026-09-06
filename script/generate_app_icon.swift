#!/usr/bin/env swift
import AppKit
import Foundation

/// Hand-crafted StayDuo icon — sun (keep display) + wifi arcs (keep network).
/// Code-drawn geometry, not an AI image.

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("no graphics context\n", stderr)
    exit(1)
}
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let corner = size * 0.2237
let bgPath = CGPath(roundedRect: bounds, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

let bgColors = [
    NSColor(calibratedRed: 0.05, green: 0.055, blue: 0.07, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.07, alpha: 1).cgColor,
] as CFArray
if let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: bgColors,
    locations: [0, 1]
) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: size * 0.15, y: size * 0.9),
        end: CGPoint(x: size * 0.85, y: size * 0.1),
        options: []
    )
}

let mint = NSColor(calibratedRed: 0.18, green: 0.95, blue: 0.72, alpha: 1)
let amber = NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.14, alpha: 1)
let sunCore = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1)

func strokeArc(
    center: CGPoint,
    radius: CGFloat,
    lineWidth: CGFloat,
    startDeg: CGFloat,
    sweepDeg: CGFloat,
    color: NSColor
) {
    let start = (startDeg - 90) * .pi / 180
    let end = (startDeg + sweepDeg - 90) * .pi / 180
    let path = CGMutablePath()
    path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.addPath(path)
    ctx.strokePath()
}

func fillDot(at center: CGPoint, radius: CGFloat, color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
}

func drawRay(from origin: CGPoint, clockDeg: CGFloat, inner: CGFloat, outer: CGFloat, width: CGFloat, color: NSColor) {
    let a = (clockDeg - 90) * .pi / 180
    let start = CGPoint(x: origin.x + inner * cos(a), y: origin.y + inner * sin(a))
    let end = CGPoint(x: origin.x + outer * cos(a), y: origin.y + outer * sin(a))
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: start)
    ctx.addLine(to: end)
    ctx.strokePath()
}

let mid = CGPoint(x: size * 0.50, y: size * 0.54)
let sunRadius = size * 0.145

for i in 0..<8 {
    let deg = CGFloat(i) * 45
    drawRay(
        from: mid,
        clockDeg: deg,
        inner: sunRadius + size * 0.045,
        outer: sunRadius + size * 0.125,
        width: size * 0.038,
        color: amber
    )
}

ctx.setFillColor(sunCore.cgColor)
ctx.fillEllipse(in: CGRect(
    x: mid.x - sunRadius,
    y: mid.y - sunRadius,
    width: sunRadius * 2,
    height: sunRadius * 2
))
ctx.setStrokeColor(amber.cgColor)
ctx.setLineWidth(size * 0.028)
ctx.strokeEllipse(in: CGRect(
    x: mid.x - sunRadius,
    y: mid.y - sunRadius,
    width: sunRadius * 2,
    height: sunRadius * 2
))

let wifiCenter = CGPoint(x: size * 0.50, y: size * 0.22)
strokeArc(center: wifiCenter, radius: size * 0.22, lineWidth: size * 0.055, startDeg: 232, sweepDeg: 76, color: mint)
strokeArc(center: wifiCenter, radius: size * 0.135, lineWidth: size * 0.055, startDeg: 238, sweepDeg: 64, color: mint.withAlphaComponent(0.85))
fillDot(at: CGPoint(x: wifiCenter.x, y: wifiCenter.y + size * 0.018), radius: size * 0.028, color: mint)

ctx.saveGState()
let sheenRect = CGRect(x: size * 0.08, y: size * 0.62, width: size * 0.55, height: size * 0.32)
ctx.addEllipse(in: sheenRect)
ctx.clip()
ctx.setFillColor(NSColor.white.withAlphaComponent(0.05).cgColor)
ctx.fill(bounds)
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("png encode failed\n", stderr)
    exit(1)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
