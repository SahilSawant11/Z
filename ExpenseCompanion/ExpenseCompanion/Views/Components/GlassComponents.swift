//
//  GlassComponents.swift
//  ExpenseCompanion
//
//  Dark fintech design system. All cards use dark frosted glass.
//  The hero card uses a hot-pink → purple gradient.
//

import SwiftUI

// MARK: - App Colors

extension Color {
    static let appBackground   = Color(red: 0.051, green: 0.051, blue: 0.063) // #0D0D10
    static let cardSurface     = Color.white.opacity(0.05)
    static let cardBorder      = Color.white.opacity(0.09)
    static let textPrimary     = Color.white
    static let textSecondary   = Color.white.opacity(0.45)
    static let textTertiary    = Color.white.opacity(0.28)
    static let heroPink        = Color(red: 1.0,   green: 0.176, blue: 0.471) // #FF2D78
    static let heroPurple      = Color(red: 0.753, green: 0.149, blue: 0.827) // #C026D3
    static let heroDeep        = Color(red: 0.486, green: 0.231, blue: 0.929) // #7C3AED
    static let accentBlue      = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let accentIndigo    = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
}

// MARK: - Dark Background

struct DynamicGradientBackground: View {
    // Keep EnvironmentObject signature so existing callers don't break,
    // but we no longer use it — background is always deep dark.
    @EnvironmentObject private var timeProvider: TimeOfDayProvider

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // Subtle radial glow at top — like the reference screenshots
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.06, blue: 0.50).opacity(0.55),
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

// MARK: - Dark Glass Card

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardSurface)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Hero Gradient Card

/// The showpiece pink-magenta-purple gradient card.
struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.heroPink, .heroPurple, .heroDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Dot-matrix texture overlay
            DotMatrixView()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .blendMode(.plusLighter)
                .opacity(0.18)

            // Subtle inner glow at top
            VStack {
                Ellipse()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 220, height: 80)
                    .blur(radius: 30)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            content
                .padding(22)
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
            let spacingX = geo.size.width / CGFloat(columns)
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
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
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
            Circle()
                .stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            // Glow
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
                .font(.system(size: 11, weight: .semibold, design: .default))
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
            .background(
                Circle()
                    .fill(category.color.opacity(0.15))
            )
    }
}
