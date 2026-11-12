//
//  WidgetDesign.swift
//  ExpenseCompanionWidgets
//
//  Widget-side copy of the app's design language (the extension can't see
//  the app's GlassComponents): near-black canvas, flat charcoal panels, one
//  solid pink accent with dark ink, big light numerals, tick-scale gauges.
//

import SwiftUI

enum W {
    static let bg     = Color(red: 0.043, green: 0.043, blue: 0.047)   // #0B0B0C
    static let card   = Color(red: 0.102, green: 0.102, blue: 0.110)   // #1A1A1C
    static let raised = Color(red: 0.149, green: 0.149, blue: 0.161)   // #262629
    static let pink   = Color(red: 1.0,   green: 0.176, blue: 0.471)   // #FF2D78
    static let ink    = Color(red: 0.067, green: 0.067, blue: 0.071)   // #111112, text on pink
    static let red    = Color(red: 1.0,   green: 0.27,  blue: 0.23)

    static let text1  = Color(red: 0.961, green: 0.957, blue: 0.945)
    static let text2  = Color.white.opacity(0.55)
    static let text3  = Color.white.opacity(0.32)

    /// "12,450" with Indian grouping for INR, western otherwise. No decimals.
    static func grouped(_ value: Double, currencyCode: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: currencyCode == "INR" ? "en_IN" : "en_US")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
    }
}

// MARK: - Big light amount

/// "₹ 12,450": small raised symbol, large light digits.
struct WAmount: View {
    let symbol: String
    let value: String
    var size: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(symbol)
                .font(.system(size: size * 0.38, weight: .regular))
                .padding(.top, size * 0.1)
            Text(value)
                .font(.system(size: size, weight: .light))
                .kerning(-size * 0.03)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Tick gauge (no GeometryReader, so it never clips in Live Activities)

/// Row of evenly spaced ticks. Ticks before the marker are lit; the marker
/// tick is taller and coloured.
struct WTickGauge: View {
    var progress: Double
    var ticks: Int = 32
    var height: CGFloat = 22
    var lit: Color = W.text1
    var dim: Color = Color.white.opacity(0.2)
    var marker: Color = W.pink

    var body: some View {
        let p = min(max(progress, 0), 1)
        let markerIndex = Int((p * Double(ticks - 1)).rounded())

        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<ticks, id: \.self) { i in
                let isMarker = i == markerIndex
                let isMajor = i % 4 == 0
                Capsule()
                    .fill(isMarker ? marker : (i < markerIndex ? lit : dim))
                    .frame(width: isMarker ? 3 : 1.5,
                           height: isMarker ? height : (isMajor ? height * 0.6 : height * 0.4))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

// MARK: - Corner ring

struct WRing: View {
    let progress: Double
    var tint: Color
    var lineWidth: CGFloat = 3
    var size: CGFloat = 38
    var showsLabel: Bool = true

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                    .font(.system(size: size * 0.26, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
    }
}
