//
//  GlobeGeometry.swift
//  Tweli
//
//  Backing data + math for the realistic Earth in the "distance between us"
//  card. The coastlines and graticule are pre-projected with d3.geoOrthographic
//  (Globe.jsx, world-atlas 110m) and shipped as SVG path strings in
//  GlobeGeometry.json — decoded once here into SwiftUI `Path`s so we draw a
//  pixel-identical globe with no d3 runtime. Pins, the great-circle route and
//  the plane are projected live from lon/lat using the same orthographic
//  transform, so they land exactly on the baked geography.
//
//  Everything lives in the design's 300×264 viewBox (globe at (150,138) r104).
//

import SwiftUI
import CoreGraphics

enum GlobeGeometry {

    // MARK: - Design constants (must match Globe.jsx / GlobeGeometry.json)

    static let viewBox = CGSize(width: 300, height: 264)
    static let center  = CGPoint(x: 150, y: 138)
    static let radius: CGFloat = 104

    // Cities the design centers on: [lon, lat].
    static let puducherry = (lon: 79.83, lat: 11.93)   // blue — "you"
    static let abuDhabi   = (lon: 54.37, lat: 24.45)   // red  — partner

    static let centerLon = (puducherry.lon + abuDhabi.lon) / 2   // 67.10
    static let centerLat = (puducherry.lat + abuDhabi.lat) / 2   // 18.19

    // MARK: - Baked coastline + graticule (decoded once, cached)

    private static let baked: (land: Path, graticule: Path) = {
        guard let url = Bundle.main.url(forResource: "GlobeGeometry", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (Path(), Path()) }
        let land = parse((obj["land"] as? String) ?? "")
        let grat = parse((obj["graticule"] as? String) ?? "")
        return (land, grat)
    }()

    static var landPath: Path { baked.land }
    static var graticulePath: Path { baked.graticule }

    // MARK: - Orthographic forward projection (matches d3.geoOrthographic)

    /// Projects a [lon,lat] (degrees) to the 300×264 viewBox. `visible` is false
    /// for points on the far hemisphere (d3 clipAngle 90°, threshold 0.02 rad).
    static func project(lon: Double, lat: Double) -> (point: CGPoint, visible: Bool) {
        let lon0 = centerLon * .pi / 180, lat0 = centerLat * .pi / 180
        let λ = lon * .pi / 180 - lon0
        let φ = lat * .pi / 180
        let cosc = sin(lat0) * sin(φ) + cos(lat0) * cos(φ) * cos(λ)
        let x = Double(radius) * cos(φ) * sin(λ)
        let y = Double(radius) * (cos(lat0) * sin(φ) - sin(lat0) * cos(φ) * cos(λ))
        let pt = CGPoint(x: Double(center.x) + x, y: Double(center.y) - y)
        return (pt, cosc >= sin(0.02))
    }

    /// Great-circle interpolation between two [lon,lat] points (d3.geoInterpolate).
    static func interpolate(_ a: (lon: Double, lat: Double),
                            _ b: (lon: Double, lat: Double), _ t: Double) -> (lon: Double, lat: Double) {
        let a3 = toCartesian(a), b3 = toCartesian(b)
        let dot = max(-1, min(1, a3.x * b3.x + a3.y * b3.y + a3.z * b3.z))
        let d = acos(dot)                       // angular distance
        if d < 1e-6 { return a }
        let sA = sin((1 - t) * d) / sin(d)
        let sB = sin(t * d) / sin(d)
        let x = sA * a3.x + sB * b3.x
        let y = sA * a3.y + sB * b3.y
        let z = sA * a3.z + sB * b3.z
        let lon = atan2(y, x) * 180 / .pi
        let lat = atan2(z, (x * x + y * y).squareRoot()) * 180 / .pi
        return (lon, lat)
    }

    // MARK: - The route (single source of truth for the arc AND the plane)

    /// One projected sample of the great-circle route `a` → `b` at parameter `t`.
    ///
    /// The arc and the plane in DistanceJourneyView BOTH go through this. They
    /// used to each do their own interpolate-then-project, which is how the
    /// plane kept flying the design comp's fixed India→UAE line after the arc
    /// had been moved onto the couple's real coordinates. Divergence is now a
    /// compile-time impossibility rather than something a reviewer has to spot.
    static func routeSample(from a: (lon: Double, lat: Double),
                            to b: (lon: Double, lat: Double),
                            t: Double) -> (point: CGPoint, visible: Bool) {
        let g = interpolate(a, b, min(max(t, 0), 1))
        return project(lon: g.lon, lat: g.lat)
    }

    /// Where the little plane sits at `t`, plus the screen-space bearing to
    /// rotate it by (radians, 0 = pointing right in viewBox coordinates).
    static func routePlane(from a: (lon: Double, lat: Double),
                           to b: (lon: Double, lat: Double),
                           t: Double) -> (point: CGPoint, visible: Bool, bearing: Double) {
        let dt = 0.012
        let t0 = min(max(t, 0), 1)
        // Sample the tangent forward, except at the very end: a forward
        // lookahead there collapses onto the same point and atan2(0, 0) would
        // snap the nose due east for the whole hold. Sample backwards instead.
        let ahead = t0 + dt <= 1
        let (ta, tb) = ahead ? (t0, t0 + dt) : (max(0, t0 - dt), t0)
        let p0 = routeSample(from: a, to: b, t: ta)
        let p1 = routeSample(from: a, to: b, t: tb)
        let here = ahead ? p0 : p1       // the sample that is actually at `t`
        let d = CGPoint(x: p1.point.x - p0.point.x, y: p1.point.y - p0.point.y)
        // Degenerate only when the two cities coincide; keep the last sane nose.
        let bearing = (abs(d.x) < 1e-9 && abs(d.y) < 1e-9) ? 0 : atan2(Double(d.y), Double(d.x))
        return (here.point, here.visible, bearing)
    }

    private static func toCartesian(_ p: (lon: Double, lat: Double)) -> (x: Double, y: Double, z: Double) {
        let λ = p.lon * .pi / 180, φ = p.lat * .pi / 180
        return (cos(φ) * cos(λ), cos(φ) * sin(λ), sin(φ))
    }

    // MARK: - SVG path parser (only M / L / Z, as emitted by d3.geoPath)

    private static func parse(_ d: String) -> Path {
        var path = Path()
        let bytes = Array(d.utf8)
        var i = 0
        let n = bytes.count

        func readNumber() -> CGFloat {
            // skip separators
            while i < n {
                let c = bytes[i]
                if c == 0x2C || c == 0x20 { i += 1 } else { break }   // ',' or ' '
            }
            let start = i
            while i < n {
                let c = bytes[i]
                // digit, '-', '+', '.', 'e', 'E'
                if (c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x2B || c == 0x2E || c == 0x65 || c == 0x45 {
                    i += 1
                } else { break }
            }
            return CGFloat(Double(String(decoding: bytes[start..<i], as: UTF8.self)) ?? 0)
        }

        while i < n {
            let c = bytes[i]
            switch c {
            case 0x4D:                       // 'M'
                i += 1
                let x = readNumber(), y = readNumber()
                path.move(to: CGPoint(x: x, y: y))
            case 0x4C:                       // 'L'
                i += 1
                let x = readNumber(), y = readNumber()
                path.addLine(to: CGPoint(x: x, y: y))
            case 0x5A, 0x7A:                 // 'Z' / 'z'
                i += 1
                path.closeSubpath()
            default:
                i += 1
            }
        }
        return path
    }
}
