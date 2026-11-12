//
//  GlassComponents.swift
//  ExpenseCompanion
//
//  Design system. Flat charcoal cards on a near-black canvas, one loud
//  accent (hero pink) used sparingly, big light-weight numerals, and a few
//  signature details: dot-matrix numerals, tick-scale gauges, circular
//  icon buttons. All colour tokens adapt to light / dark mode.
//
//  Names (glassCard, HeroCard, …) are kept from the previous glass style so
//  every screen picks up the new look without call-site changes.
//

import SwiftUI
import UIKit

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

// MARK: - App Colors  (adaptive via UIColor dynamic provider)

private func dynamic(dark: UIColor, light: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

extension Color {
    /// Page canvas: near-black / warm off-white.
    static let appBackground = dynamic(
        dark: UIColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1),   // #0B0B0C
        light: UIColor(red: 0.949, green: 0.945, blue: 0.937, alpha: 1)   // #F2F1EF
    )

    /// Card fill: flat charcoal / white.
    static let cardSurface = dynamic(
        dark: UIColor(red: 0.102, green: 0.102, blue: 0.110, alpha: 1),   // #1A1A1C
        light: UIColor.white
    )

    /// Controls sitting on a card (circle buttons, badges).
    static let cardSurfaceRaised = dynamic(
        dark: UIColor(red: 0.149, green: 0.149, blue: 0.161, alpha: 1),   // #262629
        light: UIColor(red: 0.937, green: 0.933, blue: 0.925, alpha: 1)   // #EFEEEC
    )

    /// Hairlines and dividers.
    static let cardBorder = dynamic(
        dark: UIColor(white: 1, alpha: 0.08),
        light: UIColor(white: 0, alpha: 0.08)
    )

    static let textPrimary = dynamic(
        dark: UIColor(red: 0.961, green: 0.957, blue: 0.945, alpha: 1),   // #F5F4F1
        light: UIColor(red: 0.067, green: 0.067, blue: 0.071, alpha: 1)   // #111112
    )

    static let textSecondary = dynamic(
        dark: UIColor(white: 1, alpha: 0.55),
        light: UIColor(white: 0, alpha: 0.55)
    )

    static let textTertiary = dynamic(
        dark: UIColor(white: 1, alpha: 0.32),
        light: UIColor(white: 0, alpha: 0.35)
    )

    // ── Accent (same in both modes) ─────────────────────────────────────
    static let heroPink    = Color(red: 1.0,   green: 0.176, blue: 0.471) // #FF2D78
    /// Text and marks drawn on top of the pink accent.
    static let onAccent    = Color(red: 0.067, green: 0.067, blue: 0.071) // #111112

    // Secondary hues, kept for data (categories, statuses), not for chrome.
    static let heroPurple  = Color(red: 0.753, green: 0.149, blue: 0.827) // #C026D3
    static let heroDeep    = Color(red: 0.486, green: 0.231, blue: 0.929) // #7C3AED
    static let accentBlue  = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let accentIndigo = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
}

// MARK: - Background

/// Flat canvas. (Kept as a view so screens can swap in texture later.)
struct DynamicGradientBackground: View {
    var body: some View {
        Color.appBackground.ignoresSafeArea()
    }
}

// MARK: - Card

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardSurface)
            )
            // Dark mode relies on contrast alone; light mode gets a whisper of lift.
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 28, padding: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Hero Card (the one loud accent per screen)

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.onAccent)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.heroPink)
            )
    }
}

// MARK: - Big Amount

/// Large, light-weight figure with a small raised currency symbol: "₹ 12,450".
struct BigAmount: View {
    let amount: Double
    var currencyCode: String = "INR"
    var size: CGFloat = 52
    var weight: Font.Weight = .light
    var showsDecimals: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            Text(CurrencyFormatter.symbol(for: currencyCode))
                .font(.system(size: size * 0.36, weight: .regular))
                .padding(.top, size * 0.12)
            Text(Self.grouped(amount, currencyCode: currencyCode, decimals: showsDecimals))
                .font(.system(size: size, weight: weight))
                .monospacedDigit()
                .kerning(-size * 0.03)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    static func grouped(_ amount: Double, currencyCode: String, decimals: Bool = false) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: currencyCode == "INR" ? "en_IN" : "en_US")
        f.maximumFractionDigits = decimals ? 2 : 0
        f.minimumFractionDigits = decimals ? 2 : 0
        return f.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

// MARK: - Split Title

/// Two-line title, light over bold: "Good / evening".
struct SplitTitle: View {
    let light: String
    let bold: String
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.12) {
            Text(light).font(.system(size: size, weight: .light))
            Text(bold).font(.system(size: size, weight: .bold))
        }
        .kerning(-size * 0.02)
        .foregroundStyle(Color.textPrimary)
    }
}

// MARK: - Circle Icon Button

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(filled ? Color.appBackground : Color.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? Color.textPrimary : Color.cardSurfaceRaised))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pill

struct PillBadge: View {
    let title: String
    var isSelected: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isSelected ? Color.appBackground : Color.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.textPrimary : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Color.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = .accentColor
    var trackOpacity: Double = 0.14

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

/// Small ring with the percentage inside, for card corners.
struct CornerRing: View {
    let progress: Double
    var tint: Color = Color.textPrimary
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ProgressRing(progress: progress, lineWidth: 3, tint: tint, trackOpacity: 0.18)
            Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                .font(.system(size: size * 0.26, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tick Gauge

/// Horizontal ruler with a marker at `progress` (0…1). Ticks left of the marker are lit.
struct TickGauge: View {
    var progress: Double
    var tickCount: Int = 48
    var marker: Color = .heroPink
    var height: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let p = min(max(progress, 0), 1)
            let w = geo.size.width
            let step = w / CGFloat(max(tickCount - 1, 1))
            let markerX = w * p

            ZStack(alignment: .topLeading) {
                ForEach(0..<tickCount, id: \.self) { i in
                    let x = CGFloat(i) * step
                    let major = i % 6 == 0
                    Capsule()
                        .fill(x <= markerX ? Color.textPrimary : Color.textTertiary.opacity(0.6))
                        .frame(width: 1.5, height: major ? height * 0.62 : height * 0.42)
                        .position(x: x, y: height * 0.62)
                }

                // Marker: triangle cap + bar
                VStack(spacing: 0) {
                    Triangle()
                        .fill(marker)
                        .frame(width: 10, height: 8)
                    Capsule()
                        .fill(marker)
                        .frame(width: 3, height: height - 8)
                }
                .position(x: markerX, y: height / 2)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: p)
            }
        }
        .frame(height: height)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Area Sparkline

/// Smooth area + line chart for a short series. Draws in the current foreground style.
struct AreaSparkline: View {
    let values: [Double]
    var lineWidth: CGFloat = 2
    var fillOpacity: Double = 0.18

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    area(pts, height: geo.size.height)
                        .fill(.foreground.opacity(fillOpacity))
                    line(pts)
                        .stroke(.foreground, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let maxV = max(values.max() ?? 0, 1)
        let stepX = size.width / CGFloat(values.count - 1)
        let inset = lineWidth
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX,
                    y: inset + (size.height - inset * 2) * (1 - CGFloat(v / maxV)))
        }
    }

    private func line(_ pts: [CGPoint]) -> Path {
        Path { p in
            p.move(to: pts[0])
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                p.addQuadCurve(to: mid, control: CGPoint(x: (a.x + mid.x) / 2, y: a.y))
                p.addQuadCurve(to: b, control: CGPoint(x: (mid.x + b.x) / 2, y: b.y))
            }
        }
    }

    private func area(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = line(pts)
        p.addLine(to: CGPoint(x: pts.last!.x, y: height))
        p.addLine(to: CGPoint(x: pts[0].x, y: height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Dot Matrix Text

/// Renders text in a 5×7 dot-matrix face. Supports 0–9, A–Z and a few symbols.
struct DotMatrixText: View {
    let text: String
    var dot: CGFloat = 4
    var gap: CGFloat = 2
    var color: Color = Color.textPrimary

    var body: some View {
        let glyphs = text.uppercased().map { DotMatrixFont.glyph(for: $0) }
        let pitch = dot + gap
        let columns = glyphs.reduce(0) { $0 + $1.width } + max(glyphs.count - 1, 0)
        let width = max(CGFloat(columns) * pitch - gap, 0)
        let height = 7 * pitch - gap

        Canvas { ctx, _ in
            var col = 0
            for g in glyphs {
                for (r, row) in g.rows.enumerated() {
                    for (c, ch) in row.enumerated() where ch == "#" {
                        let rect = CGRect(x: CGFloat(col + c) * pitch, y: CGFloat(r) * pitch, width: dot, height: dot)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
                col += g.width + 1
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel(text)
    }
}

enum DotMatrixFont {
    struct Glyph {
        let rows: [[Character]]
        var width: Int { rows.first?.count ?? 0 }
    }

    static func glyph(for ch: Character) -> Glyph {
        let rows = table[ch] ?? table[" "]!
        return Glyph(rows: rows.map(Array.init))
    }

    private static let table: [Character: [String]] = [
        "0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
        "1": ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
        "2": [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
        "3": ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "],
        "4": ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
        "5": ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
        "6": ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "],
        "7": ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
        "8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
        "9": [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "],
        "A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
        "B": ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
        "C": [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
        "D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
        "E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
        "F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
        "G": [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ####"],
        "H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
        "I": [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
        "J": ["  ###", "   # ", "   # ", "   # ", "   # ", "#  # ", " ##  "],
        "K": ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
        "L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
        "M": ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
        "N": ["#   #", "#   #", "##  #", "# # #", "#  ##", "#   #", "#   #"],
        "O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
        "P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
        "Q": [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"],
        "R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
        "S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
        "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
        "U": ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
        "V": ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
        "W": ["#   #", "#   #", "#   #", "# # #", "# # #", "# # #", " # # "],
        "X": ["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"],
        "Y": ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
        "Z": ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"],
        " ": ["  ", "  ", "  ", "  ", "  ", "  ", "  "],
        ".": [" ", " ", " ", " ", " ", " ", "#"],
        ",": [" ", " ", " ", " ", " ", "#", "#"],
        ":": [" ", "#", " ", " ", " ", "#", " "],
        "-": ["   ", "   ", "   ", "###", "   ", "   ", "   "],
        "/": ["    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    "],
        "%": ["##  #", "##  #", "   # ", "  #  ", " #   ", "#  ##", "#  ##"],
        "+": ["     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     "],
        "₹": ["#####", "   # ", "#####", "  #  ", "##   ", "  #  ", "   ##"],
        "€": ["  ###", " #   ", "#### ", " #   ", "#### ", " #   ", "  ###"],
    ]
}

// MARK: - Section Header

struct GlassSectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(Color.textSecondary)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.cardSurfaceRaised))
    }
}

// MARK: - Legacy decoration

/// Dot grid decoration. No longer used by HeroCard; kept for any screen that still wants it.
struct DotMatrixView: View {
    let columns = 10
    let rows = 6

    var body: some View {
        GeometryReader { geo in
            let spacingX = geo.size.width  / CGFloat(columns)
            let spacingY = geo.size.height / CGFloat(rows)

            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { col in
                    let x = spacingX * CGFloat(col) + spacingX / 2
                    let y = spacingY * CGFloat(row) + spacingY / 2
                    let isFilled = (row + col) % 3 == 0
                    Circle()
                        .fill(Color.white)
                        .opacity(isFilled ? 0.9 : 0.25)
                        .frame(width: isFilled ? 4 : 3, height: isFilled ? 4 : 3)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
