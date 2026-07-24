//
//  DistanceJourneyView.swift
//  Tweli
//
//  "The distance between us" — the half-sheet opened by tapping the "N km apart"
//  side of the closeness strip (design: distL/distD). A stylized 3-D globe fills
//  the map card; an arc routes from your city to your partner's while a little
//  plane flies it, and three tiles read km apart · days together · days to go.
//
//  Reproduced 1:1 from the design's 300×264 SVG. The globe body is drawn in a
//  Canvas (ocean gradient, continents, clouds, graticule, shading, specular);
//  the route, pins, plane and labels are SwiftUI layered on top. Everything is
//  authored in the 300×264 space and scaled to fit the card.
//

import SwiftUI

struct DistanceJourneyView: View {
    let myCity: String          // "Chennai, India" — full string for the subtitle
    let partnerCity: String
    let distanceLabel: String   // "2,912 km"
    let daysTogether: Int?
    let daysToGo: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var planeStart = Date()

    // Design viewBox (300×264). Globe geometry + projection live in GlobeGeometry:
    // pins, the great-circle route and the plane are projected from real lon/lat.
    private static let vb = GlobeGeometry.viewBox

    // Design route + pin colors (Globe.jsx).
    private let arcGold = Color(red: 1.0, green: 0.824, blue: 0.290)   // #FFD24A
    private let pinBlue = Color(red: 0.039, green: 0.518, blue: 1.000) // #0A84FF
    private let pinRed  = Color(red: 1.000, green: 0.176, blue: 0.333) // #FF2D55

    private var myCityShort: String { String(myCity.split(separator: ",").first ?? "") }
    private var partnerCityShort: String { String(partnerCity.split(separator: ",").first ?? "") }

    // Exact design palette (hex → RGB).
    private let inkTitle   = Color(red: 0.110, green: 0.110, blue: 0.118)  // #1C1C1E
    private let inkSub     = Color(red: 0.427, green: 0.427, blue: 0.447)  // #6D6D72
    private let closeGrey  = Color(red: 0.541, green: 0.541, blue: 0.557)  // #8A8A8E
    private let tileBlue   = Color(red: 0.039, green: 0.518, blue: 1.000)  // #0A84FF
    private let tilePink   = Color(red: 1.000, green: 0.176, blue: 0.333)  // #FF2D55
    private let tileRed    = Color(red: 0.886, green: 0.231, blue: 0.353)  // #E23B5A
    private let cardTop    = Color(red: 0.918, green: 0.949, blue: 1.000)  // #EAF2FF
    private let cardBottom = Color(red: 0.992, green: 0.933, blue: 0.953)  // #FDEEF3
    private let cardBorder = Color(red: 0.353, green: 0.690, blue: 1.000)  // #5AB0FF

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            mapCard
            tiles
                .padding(.top, 8)   // let the stat tiles breathe below the globe card
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // #F2F2F7 grouped grey so the white stat tiles read as cards (design).
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
        .onAppear { planeStart = Date() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("The distance between us")
                    .font(.system(size: 22, weight: .heavy)).kerning(-0.5)
                    .foregroundStyle(scheme == .dark ? Color.white : inkTitle)
                Text("\(myCity) → \(partnerCity)")
                    .font(.system(size: 13)).foregroundStyle(inkSub)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(closeGrey)
                    .frame(width: 30, height: 30)
                    .background(Color(red: 0.471, green: 0.471, blue: 0.502).opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Map card (globe + route + pins + plane + labels)

    private var mapCard: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / Self.vb.width, geo.size.height / Self.vb.height)
            art
                .frame(width: Self.vb.width, height: Self.vb.height)
                .scaleEffect(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        // A compact near-square card (design) rather than stretching to fill the
        // sheet — keeps the globe large and leaves the tiles room to breathe below.
        .frame(maxWidth: .infinity)
        .aspectRatio(1.06, contentMode: .fit)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(scheme == .dark ? Color.white.opacity(0.06) : cardBorder.opacity(0.25),
                          lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The full 300×264 artwork.
    private var art: some View {
        let pud = GlobeGeometry.project(lon: GlobeGeometry.puducherry.lon,
                                        lat: GlobeGeometry.puducherry.lat).point   // blue — you
        let abu = GlobeGeometry.project(lon: GlobeGeometry.abuDhabi.lon,
                                        lat: GlobeGeometry.abuDhabi.lat).point      // red  — partner
        return ZStack {
            GlobeCanvas(dark: scheme == .dark)

            // Great-circle route: white underlay + gold, always fully drawn (design).
            arcPath.stroke(.white.opacity(0.6),
                           style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            arcPath.stroke(arcGold, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            // Plane flying the route, looping (dur 5.2s + 0.9s hold, per Globe.jsx).
            TimelineView(.animation) { tl in
                planeView(at: planeProgress(tl.date))
            }

            // Pins (tip on the projected city coordinates).
            pin(color: pinBlue, tip: pud)
            pin(color: pinRed,  tip: abu)

            cityLabel(myCityShort).position(x: pud.x, y: pud.y + 26)
            cityLabel(partnerCityShort).position(x: abu.x, y: abu.y - 30)
        }
        .frame(width: Self.vb.width, height: Self.vb.height)
    }

    /// Plane at great-circle parameter `t`, oriented along its bearing.
    private func planeView(at t: CGFloat) -> some View {
        let g  = GlobeGeometry.interpolate(GlobeGeometry.puducherry, GlobeGeometry.abuDhabi, Double(t))
        let g2 = GlobeGeometry.interpolate(GlobeGeometry.puducherry, GlobeGeometry.abuDhabi,
                                           Double(min(1, t + 0.012)))
        let s  = GlobeGeometry.project(lon: g.lon,  lat: g.lat)
        let s2 = GlobeGeometry.project(lon: g2.lon, lat: g2.lat)
        let bearing = atan2(s2.point.y - s.point.y, s2.point.x - s.point.x)
        return PlaneTriangle()
            .fill(.white)
            .overlay(PlaneTriangle().stroke(Color(red: 0.788, green: 0.565, blue: 0.165),
                                            lineWidth: 0.8))
            .frame(width: 12, height: 15)
            .rotationEffect(.radians(bearing) + .degrees(90))
            .position(s.point)
            .opacity(s.visible ? 1 : 0)
    }

    private func pin(color: Color, tip: CGPoint) -> some View {
        let w: CGFloat = 24, h: CGFloat = 31
        return ZStack {
            MapPinShape().fill(color)
                .overlay(MapPinShape().stroke(.white, lineWidth: 1.4))
            Circle().fill(.white).frame(width: 8, height: 8).offset(y: -h * 0.19)
        }
        .frame(width: w, height: h)
        .position(x: tip.x, y: tip.y - h / 2)
    }

    private func cityLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.black)
            .shadow(color: .white, radius: 1.5)
            .shadow(color: .white, radius: 1.5)
    }

    // MARK: - Stat tiles

    private var tiles: some View {
        HStack(spacing: 9) {
            tile(distanceValue, distanceUnit + " apart", tileBlue)
            tile(daysTogether.map(String.init) ?? "—", "days together", tilePink)
            tile(daysToGo.map(String.init) ?? "—", "days to go", tileRed)
        }
    }

    private func tile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 19, weight: .heavy)).kerning(-0.3)
                .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(inkSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    private var distanceValue: String {
        let parts = distanceLabel.split(separator: " ")
        return parts.count > 1 ? parts.dropLast().joined(separator: " ") : distanceLabel
    }
    private var distanceUnit: String {
        let parts = distanceLabel.split(separator: " ")
        return parts.count > 1 ? String(parts.last!) : "km"
    }

    // MARK: - Card background

    @ViewBuilder private var cardBackground: some View {
        if scheme == .dark {
            LinearGradient(colors: [Color(red: 0.078, green: 0.098, blue: 0.137),
                                    Color(red: 0.043, green: 0.055, blue: 0.078)],
                           startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: [cardTop, cardBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - Route geometry (great-circle, projected — matches the baked globe)

    /// The great-circle arc from you → partner, sampled and projected. Segments
    /// on the far hemisphere are dropped so the line stays on the visible face.
    private var arcPath: Path {
        var p = Path()
        var started = false
        let n = 80
        for i in 0...n {
            let g = GlobeGeometry.interpolate(GlobeGeometry.puducherry, GlobeGeometry.abuDhabi,
                                              Double(i) / Double(n))
            let pr = GlobeGeometry.project(lon: g.lon, lat: g.lat)
            guard pr.visible else { started = false; continue }
            if started { p.addLine(to: pr.point) } else { p.move(to: pr.point); started = true }
        }
        return p
    }

    /// Looping plane parameter: fly over 5.2s, hold 0.9s, restart (Globe.jsx).
    private func planeProgress(_ date: Date) -> CGFloat {
        let dur = 5.2, hold = 0.9, cycle = dur + hold
        let elapsed = date.timeIntervalSince(planeStart).truncatingRemainder(dividingBy: cycle)
        return CGFloat(min(1, max(0, elapsed) / dur))
    }
}

/// The design's little plane glyph (Globe.jsx: M0 -8 L4.5 5 L0 2.5 L-4.5 5 Z),
/// nose pointing up, drawn centered in its frame.
private struct PlaneTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x, y: c.y + y) }
        var p = Path()
        p.move(to: pt(0, -8))
        p.addLine(to: pt(4.5, 5))
        p.addLine(to: pt(0, 2.5))
        p.addLine(to: pt(-4.5, 5))
        p.closeSubpath()
        return p
    }
}

/// A classic filled map-pin teardrop (tip at bottom-center), sized to its frame.
private struct MapPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, cx = rect.midX, r = w / 2
        let cy = rect.minY + r
        var p = Path()
        p.move(to: CGPoint(x: cx, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: cy),
                   control1: CGPoint(x: cx - r * 0.55, y: rect.maxY - h * 0.32),
                   control2: CGPoint(x: rect.minX, y: cy + r * 0.7))
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: cx, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: cy + r * 0.7),
                   control2: CGPoint(x: cx + r * 0.55, y: rect.maxY - h * 0.32))
        p.closeSubpath()
        return p
    }
}
