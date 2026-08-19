//
//  GlobeRouteTests.swift
//  TweliTests
//
//  The distance sheet draws a gold great-circle arc between the two of you and
//  flies a little plane along it. Those were two independent projections of two
//  independently chosen endpoint pairs, and they drifted apart: the arc was
//  moved onto the couple's real coordinates while the plane kept interpolating
//  the design comp's fixed Puducherry → Abu Dhabi pair. The result was a plane
//  crossing empty ocean beside a route it never touched.
//
//  Nothing about that is visible in a still screenshot with the plane near the
//  middle of a short route, which is why it survived a screenshot pass. These
//  tests pin the invariant directly: for any pair of cities, at any point in the
//  flight, the plane is ON the line.
//

import Testing
import Foundation
import CoreGraphics
@testable import Tweli

@Suite("Globe route")
struct GlobeRouteTests {

    // Real coordinates, deliberately NOT the design's own pair — a plane stuck
    // on the hardcoded India/UAE line lands hundreds of points away from these.
    private static let london     = (lon: -0.1276, lat: 51.5072)
    private static let bengaluru  = (lon: 77.5946, lat: 12.9716)
    private static let paris      = (lon: 2.3522, lat: 48.8566)
    private static let nairobi    = (lon: 36.8219, lat: -1.2921)
    private static let designPair = (GlobeGeometry.puducherry, GlobeGeometry.abuDhabi)

    /// The arc exactly as `DistanceJourneyView.arcPath` builds it: 81 samples,
    /// far-hemisphere points dropped, drawn as straight segments between the
    /// survivors.
    private func arcSegments(_ a: (lon: Double, lat: Double),
                             _ b: (lon: Double, lat: Double)) -> [(CGPoint, CGPoint)] {
        var segs: [(CGPoint, CGPoint)] = []
        var previous: CGPoint?
        let n = 80
        for i in 0...n {
            let s = GlobeGeometry.routeSample(from: a, to: b, t: Double(i) / Double(n))
            guard s.visible else { previous = nil; continue }
            if let p = previous { segs.append((p, s.point)) }
            previous = s.point
        }
        return segs
    }

    private func distance(_ p: CGPoint, toSegment s: (CGPoint, CGPoint)) -> Double {
        let (a, b) = s
        let vx = Double(b.x - a.x), vy = Double(b.y - a.y)
        let wx = Double(p.x - a.x), wy = Double(p.y - a.y)
        let len2 = vx * vx + vy * vy
        let t = len2 < 1e-12 ? 0 : max(0, min(1, (wx * vx + wy * vy) / len2))
        let dx = wx - t * vx, dy = wy - t * vy
        return (dx * dx + dy * dy).squareRoot()
    }

    private func distanceToArc(_ p: CGPoint, _ segs: [(CGPoint, CGPoint)]) -> Double {
        segs.map { distance(p, toSegment: $0) }.min() ?? .infinity
    }

    @Test("the plane flies the arc that is drawn, for every pair",
          arguments: [(london, bengaluru), (bengaluru, london),
                      (paris, nairobi), (nairobi, paris),
                      designPair])
    func planeStaysOnTheDrawnArc(pair: ((lon: Double, lat: Double), (lon: Double, lat: Double))) {
        let segs = arcSegments(pair.0, pair.1)
        #expect(!segs.isEmpty, "this pair should be drawable on the visible hemisphere")

        // Sample the flight far more finely than the arc is drawn, so a plane on
        // a different route cannot slip through between checks.
        for step in 0...200 {
            let t = Double(step) / 200
            let f = GlobeGeometry.routePlane(from: pair.0, to: pair.1, t: t)
            guard f.visible else { continue }   // hidden behind the globe, not drawn
            let d = distanceToArc(f.point, segs)
            // The arc is a chord approximation of the curve, so the plane sits a
            // hair off it by construction. 0.5pt in a 300x264 viewBox is invisible;
            // the regression this guards against was off by 50-200pt.
            #expect(d < 0.5, "plane is \(d)pt off the drawn arc at t=\(t)")
        }
    }

    @Test("the plane starts on your pin and ends on your partner's")
    func planeEndpointsMatchThePins() {
        let mine = GlobeGeometry.project(lon: Self.london.lon, lat: Self.london.lat)
        let theirs = GlobeGeometry.project(lon: Self.bengaluru.lon, lat: Self.bengaluru.lat)

        let start = GlobeGeometry.routePlane(from: Self.london, to: Self.bengaluru, t: 0)
        let end = GlobeGeometry.routePlane(from: Self.london, to: Self.bengaluru, t: 1)

        #expect(hypot(start.point.x - mine.point.x, start.point.y - mine.point.y) < 0.01)
        #expect(hypot(end.point.x - theirs.point.x, end.point.y - theirs.point.y) < 0.01)
    }

    /// At t = 1 a forward lookahead collapses onto the same point, and
    /// atan2(0, 0) is 0 — which used to snap the nose due east for the entire
    /// 0.9s hold at the end of every loop. The bearing must stay continuous.
    @Test("the nose does not snap at the end of the flight")
    func bearingIsContinuousThroughTheLastFrame() {
        let a = GlobeGeometry.routePlane(from: Self.london, to: Self.bengaluru, t: 0.97).bearing
        let b = GlobeGeometry.routePlane(from: Self.london, to: Self.bengaluru, t: 1.0).bearing
        var delta = abs(b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta = 2 * .pi - delta }
        #expect(delta < 0.15, "bearing jumped \(delta) rad over the last 3% of the route")
    }

    /// Two people in the same city is a real state (they met up). It must not
    /// produce a NaN position that silently removes the plane from the layer.
    @Test("a couple in the same place does not produce a NaN plane")
    func coincidentCitiesAreFinite() {
        let f = GlobeGeometry.routePlane(from: Self.london, to: Self.london, t: 0.5)
        #expect(f.point.x.isFinite && f.point.y.isFinite)
        #expect(f.bearing.isFinite)
    }
}
