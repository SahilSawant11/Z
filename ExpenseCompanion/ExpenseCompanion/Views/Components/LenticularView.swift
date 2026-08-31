//
//  LenticularView.swift
//  ExpenseCompanion
//
//  A cylindrical lenticular lens array effect. The source image is sliced
//  into thin vertical strips, each strip sampled at a sinusoidally-offset
//  horizontal position — simulating light refraction through a row of
//  glass cylinders. Bright vertical highlights between strips simulate
//  the specular reflections off each cylinder's surface.
//
//  Supports:
//    - Static rendering  (default)
//    - Drag interaction  (drag horizontally to shift the lens phase)
//    - Idle animation    (subtle auto-oscillation when not being dragged)
//

import SwiftUI

// MARK: - LenticularView

struct LenticularView: View {
    /// The image to apply the lenticular effect to.
    var image: Image
    /// Number of vertical lens strips. More = finer grating, more realistic.
    var strips: Int = 28
    /// How far each strip samples away from its natural position (0 = no effect).
    var amplitude: Double = 0.35
    /// Visual intensity of the glass highlight lines (0–1).
    var highlightIntensity: Double = 0.45
    /// Corner radius of the container.
    var cornerRadius: CGFloat = 28

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var idlePhase: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Resolve the image once — Canvas needs a resolved image
            Canvas { ctx, size in
                guard let resolved = ctx.resolveSymbol(id: "img") else { return }

                let stripWidth = size.width / CGFloat(strips)

                for i in 0..<strips {
                    let stripX = CGFloat(i) * stripWidth

                    // Phase: combine idle oscillation + drag offset
                    let dragPhase = Double(dragTranslation / w) * 2.0
                    let phase = isDragging ? dragPhase : idlePhase

                    // Sinusoidal horizontal offset for this strip
                    let sinArg = (Double(i) / Double(strips)) * .pi * 2.0 + phase * .pi
                    let offset = sin(sinArg) * amplitude * Double(size.width)

                    // Clip to strip rect, draw full image shifted horizontally
                    ctx.withCGContext { cgCtx in
                        cgCtx.saveGState()
                        let clipRect = CGRect(x: stripX, y: 0, width: stripWidth + 0.5, height: size.height)
                        cgCtx.clip(to: clipRect)
                        // Draw image shifted by offset
                        let drawRect = CGRect(x: CGFloat(offset), y: 0, width: size.width, height: size.height)
                        ctx.draw(resolved, in: drawRect)
                        cgCtx.restoreGState()
                    }

                    // Glass cylinder highlight
                    // Intensity follows a bell curve peaking at strip center
                    let normalizedI = Double(i) / Double(strips - 1)
                    let highlightPos = (sin(sinArg + .pi / 2) + 1) / 2  // 0...1, phase-aware
                    let highlightAlpha = highlightPos * highlightIntensity * 0.7

                    let highlightWidth = stripWidth * 0.25
                    let highlightX = stripX + (stripWidth - highlightWidth) / 2

                    ctx.fill(
                        Path(CGRect(x: highlightX, y: 0, width: highlightWidth, height: size.height)),
                        with: .color(.white.opacity(highlightAlpha))
                    )

                    // Edge darkening (shadow side of cylinder)
                    let shadowAlpha = (1 - highlightPos) * 0.25
                    ctx.fill(
                        Path(CGRect(x: stripX, y: 0, width: stripWidth * 0.15, height: size.height)),
                        with: .color(.black.opacity(shadowAlpha))
                    )

                    _ = normalizedI // suppress warning
                }
            } symbols: {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
                    .tag("img")
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { _ in
                        if !isDragging {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isDragging = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isDragging = false
                        }
                    }
            )
            .onAppear {
                startIdleAnimation()
            }
        }
    }

    // MARK: - Idle animation

    private func startIdleAnimation() {
        // Slow sine oscillation — one full cycle every ~5 seconds
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            idlePhase = 1.0
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Applies the cylindrical lenticular lens effect to this view.
    func lenticularEffect(strips: Int = 28, amplitude: Double = 0.3) -> some View {
        modifier(LenticularModifier(strips: strips, amplitude: amplitude))
    }
}

private struct LenticularModifier: ViewModifier {
    let strips: Int
    let amplitude: Double

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var idlePhase: Double = 0
    @State private var isDragging: Bool = false

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let w = geo.size.width

            Canvas { ctx, size in
                guard let resolved = ctx.resolveSymbol(id: "content") else { return }

                let stripWidth = size.width / CGFloat(strips)

                for i in 0..<strips {
                    let stripX = CGFloat(i) * stripWidth
                    let dragPhase = Double(dragTranslation / w) * 2.0
                    let phase = isDragging ? dragPhase : idlePhase
                    let sinArg = (Double(i) / Double(strips)) * .pi * 2.0 + phase * .pi
                    let offset = sin(sinArg) * amplitude * Double(size.width)

                    ctx.withCGContext { cgCtx in
                        cgCtx.saveGState()
                        cgCtx.clip(to: CGRect(x: stripX, y: 0, width: stripWidth + 0.5, height: size.height))
                        ctx.draw(resolved, in: CGRect(x: CGFloat(offset), y: 0, width: size.width, height: size.height))
                        cgCtx.restoreGState()
                    }

                    let highlightPos = (sin(sinArg + .pi / 2) + 1) / 2
                    let highlightWidth = stripWidth * 0.25
                    ctx.fill(
                        Path(CGRect(x: stripX + (stripWidth - highlightWidth) / 2, y: 0,
                                    width: highlightWidth, height: size.height)),
                        with: .color(.white.opacity(highlightPos * 0.35))
                    )
                }
            } symbols: {
                content
                    .frame(width: geo.size.width, height: geo.size.height)
                    .tag("content")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragTranslation) { value, state, _ in state = value.translation.width }
                .onChanged { _ in if !isDragging { withAnimation { isDragging = true } } }
                .onEnded { _ in withAnimation { isDragging = false } }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                idlePhase = 1.0
            }
        }
    }
}
