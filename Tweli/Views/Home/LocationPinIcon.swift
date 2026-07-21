//
//  LocationPinIcon.swift
//  Tweli
//
//  The exact location-marker glyph from designs 21a/b — an outlined teardrop pin
//  with a hollow dot. Reproduces the design's SVG path 1:1 (there is no matching
//  SF Symbol), drawn in the SVG's 24×24 viewBox and scaled to `size`.
//
//    path:   M12 21 s-6.5-5.5-6.5-10 a6.5 6.5 0 0 1 13 0 c0 4.5-6.5 10-6.5 10 z
//    circle: cx=12 cy=11 r=2.4   ·   stroke 1.9, round caps/joins, fill none
//

import SwiftUI

struct LocationPinIcon: View {
    var size: CGFloat = 20
    var color: Color = .twAccent

    var body: some View {
        pin
            .stroke(color, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)          // the SVG's native viewBox
            .scaleEffect(size / 24)                 // scale keeps the 1.9 stroke in proportion
            .frame(width: size, height: size)
    }

    /// Teardrop outline + inner dot, in 24×24 SVG coordinates (y-down).
    private var pin: Path {
        var p = Path()
        // Bottom tip → up the left side (SVG `s` smooth cubic; control1 == start).
        p.move(to: CGPoint(x: 12, y: 21))
        p.addCurve(to: CGPoint(x: 5.5, y: 11),
                   control1: CGPoint(x: 12, y: 21),
                   control2: CGPoint(x: 5.5, y: 15.5))
        // Top half-circle, radius 6.5 about (12,11): left (180°) over the top to right (0°).
        p.addArc(center: CGPoint(x: 12, y: 11), radius: 6.5,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        // Down the right side back to the tip (SVG `c`).
        p.addCurve(to: CGPoint(x: 12, y: 21),
                   control1: CGPoint(x: 18.5, y: 15.5),
                   control2: CGPoint(x: 12, y: 21))
        p.closeSubpath()
        // Hollow inner dot (circle r=2.4 at (12,11)).
        p.addEllipse(in: CGRect(x: 12 - 2.4, y: 11 - 2.4, width: 4.8, height: 4.8))
        return p
    }
}
