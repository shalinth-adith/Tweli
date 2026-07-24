//
//  GlobeCanvas.swift
//  Tweli
//
//  The realistic 3-D Earth inside the "distance between us" card. Draws the
//  design's Globe.jsx render 1:1: an atmosphere glow, a radial-gradient ocean
//  sphere, the real world coastlines + 15° graticule (pre-projected with
//  d3.geoOrthographic and decoded from GlobeGeometry), spherical edge-shading
//  and a specular highlight. Pure Canvas, no image assets. Palette switches
//  between the light and dark compositions from Globe.jsx's PALETTES.
//
//  Coordinate space: the design's 300×264 viewBox, globe at (150,138) r104.
//

import SwiftUI

struct GlobeCanvas: View {
    var dark: Bool = false

    private var center: CGPoint { GlobeGeometry.center }
    private var r: CGFloat { GlobeGeometry.radius }

    var body: some View {
        Canvas { ctx, _ in
            let globeRect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
            let globe = Path(ellipseIn: globeRect)
            let oceanCenter = CGPoint(x: 129.2, y: 100.6)   // gradient origin (40%,32%)

            // Atmosphere halo — soft glowing rim just outside the sphere.
            ctx.fill(Path(ellipseIn: er(center.x, center.y, 120, 120)),
                     with: .radialGradient(glow, center: center, startRadius: 0, endRadius: 120))

            // Ocean sphere.
            ctx.fill(globe, with: .radialGradient(ocean, center: oceanCenter, startRadius: 0, endRadius: 166))

            // Surface (clipped to the sphere).
            ctx.drawLayer { layer in
                layer.clip(to: globe)

                // Graticule under the land.
                layer.stroke(GlobeGeometry.graticulePath, with: .color(gratColor), lineWidth: 0.7)

                // Real coastlines.
                let land = GlobeGeometry.landPath
                layer.fill(land, with: .color(landColor))
                layer.stroke(land, with: .color(landStrokeColor), lineWidth: 0.5)

                // Spherical edge shading + specular highlight.
                layer.fill(globe, with: .radialGradient(shade, center: oceanCenter, startRadius: 0, endRadius: 150))
                var spec = layer
                spec.opacity = dark ? 0.28 : 0.5
                spec.fill(Path(ellipseIn: er(112, 98, 44, 28)),
                          with: .radialGradient(specular, center: CGPoint(x: 112, y: 98),
                                                startRadius: 0, endRadius: 44))
            }
        }
    }

    // MARK: - Palette (Globe.jsx PALETTES.light / .dark)

    private var glowHex: Color   { dark ? hex(0x3f79b8) : hex(0x9AD1FF) }
    private var ocean0: Color    { dark ? hex(0x1f5187) : hex(0x8CC7F7) }
    private var ocean1: Color    { dark ? hex(0x123c63) : hex(0x3E8FD6) }
    private var ocean2: Color    { dark ? hex(0x0c2a47) : hex(0x1E63AE) }
    private var ocean3: Color    { dark ? hex(0x06182b) : hex(0x123F72) }
    private var landColor: Color { dark ? hex(0x347044) : hex(0x63A957) }
    private var landStrokeColor: Color { dark ? hex(0x24512f) : hex(0x4A8A45) }
    private var gratColor: Color {
        dark ? Color(red: 150/255, green: 200/255, blue: 255/255).opacity(0.20)
             : Color.white.opacity(0.28)
    }

    // MARK: - Gradients

    private var glow: Gradient {
        Gradient(stops: [
            .init(color: glowHex.opacity(0), location: 0),
            .init(color: glowHex.opacity(0), location: 0.72),
            .init(color: glowHex.opacity(dark ? 0.45 : 0.55), location: 0.86),
            .init(color: glowHex.opacity(0), location: 1.0),
        ])
    }
    private var ocean: Gradient {
        Gradient(stops: [
            .init(color: ocean0, location: 0),
            .init(color: ocean1, location: 0.45),
            .init(color: ocean2, location: 0.80),
            .init(color: ocean3, location: 1.0),
        ])
    }
    private var shade: Gradient {
        Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: 0.66),
            .init(color: dark ? Color(red: 0, green: 4/255, blue: 12/255).opacity(0.72)
                              : Color(red: 4/255, green: 18/255, blue: 40/255).opacity(0.60),
                  location: 1.0),
        ])
    }
    private var specular: Gradient {
        Gradient(colors: [.white.opacity(0.7), .white.opacity(0)])
    }

    // MARK: - Helpers

    private func er(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
        CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
    }
    private func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255)
    }
}
