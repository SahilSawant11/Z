//
//  GlassComponents.swift
//  ExpenseCompanion
//
//  Reusable Apple-inspired glassmorphism building blocks: the animated
//  background gradient and the .glassCard() view modifier used throughout
//  the app so every card looks consistent.
//

import SwiftUI

// MARK: - Dynamic Background

struct DynamicGradientBackground: View {
    @EnvironmentObject private var timeProvider: TimeOfDayProvider
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = colorScheme == .dark ? DayPhase.current().darkColors : timeProvider.phase.lightColors

        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .animation(.easeInOut(duration: 2.0), value: colorScheme)
            .animation(.easeInOut(duration: 2.0), value: timeProvider.phase)
            .ignoresSafeArea()
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.06)
                          : Color.white.opacity(0.55))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.7),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 16, x: 0, y: 6)
    }
}

extension View {
    /// Applies the app-wide glassmorphism card style.
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Progress Ring

/// Circular progress indicator used for daily budget and goal progress.
struct ProgressRing: View {
    var progress: Double // 0...1
    var lineWidth: CGFloat = 10
    var tint: Color = .accentColor
    var trackOpacity: Double = 0.12

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Category Badge

/// A rounded-square SF Symbol badge matching iOS Settings icon style.
struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(category.color.gradient)
            )
    }
}
