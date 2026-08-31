//
//  GlassComponents.swift
//  ExpenseCompanion
//
//  Dark fintech design system — now fully adaptive for light + dark mode.
//  All colour tokens use UIColor's dynamic provider so they respond to
//  the user's colour-scheme preference automatically.
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

extension Color {
    /// Deep dark / warm light-lavender page background
    static let appBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.051, green: 0.051, blue: 0.063, alpha: 1)   // #0D0D10
            : UIColor(red: 0.941, green: 0.937, blue: 0.965, alpha: 1)   // #F0EEF6
    })

    /// Card fill — almost transparent on dark, solid white on light
    static let cardSurface = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.05)
            : UIColor(white: 1, alpha: 1.0)
    })

    /// Subtle card border
    static let cardBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.09)
            : UIColor(white: 0, alpha: 0.06)
    })

    /// Primary text — white / near-black
    static let textPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
    })

    /// Secondary text — 45% white / 60% dark
    static let textSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.45)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.65)
    })

    /// Tertiary / hint text
    static let textTertiary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.28)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.38)
    })

    // ── Accent colours (same in both modes) ─────────────────────────────
    static let heroPink    = Color(red: 1.0,   green: 0.176, blue: 0.471) // #FF2D78
    static let heroPurple  = Color(red: 0.753, green: 0.149, blue: 0.827) // #C026D3
    static let heroDeep    = Color(red: 0.486, green: 0.231, blue: 0.929) // #7C3AED
    static let accentBlue  = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let accentIndigo = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
}

// MARK: - Adaptive Background

struct DynamicGradientBackground: View {
    @EnvironmentObject private var timeProvider: TimeOfDayProvider
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            // Top radial glow — dramatic in dark, whisper-soft in light
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.06, blue: 0.50)
                        .opacity(colorScheme == .dark ? 0.55 : 0.06),
                    Color.clear
                ],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Adaptive Glass Card

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.cardSurface : Color.white)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            }
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.45) : .black.opacity(0.07),
                radius: colorScheme == .dark ? 20 : 14,
                x: 0, y: colorScheme == .dark ? 8 : 5
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Hero Gradient Card (always vibrant — no dark/light change)

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.heroPink, .heroPurple, .heroDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            DotMatrixView()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .blendMode(.plusLighter)
                .opacity(0.18)

            VStack {
                Ellipse()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 220, height: 80)
                    .blur(radius: 30)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            content.padding(22)
        }
        .shadow(color: Color.heroPink.opacity(0.35), radius: 28, x: 0, y: 10)
    }
}

// MARK: - Dot Matrix Decoration

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

// MARK: - Pill Badge

struct PillBadge: View {
    let title: String
    var isSelected: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isSelected ? Color.black : Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.cardBorder)
            )
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = .accentColor
    var trackOpacity: Double = 0.1

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Section Header

struct GlassSectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.0)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(Circle().fill(category.color.opacity(0.15)))
    }
}
