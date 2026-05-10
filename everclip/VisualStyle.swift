//
//  VisualStyle.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI

struct StaticBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    var forcedScheme: ColorScheme?

    private var effectiveScheme: ColorScheme {
        forcedScheme ?? colorScheme
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveScheme == .dark
                    ? [
                        Color(red: 0.030, green: 0.036, blue: 0.052),
                        Color(red: 0.055, green: 0.072, blue: 0.100),
                        Color(red: 0.026, green: 0.032, blue: 0.045)
                    ]
                    : [
                        Color(red: 0.955, green: 0.970, blue: 0.980),
                        Color(red: 0.915, green: 0.940, blue: 0.960),
                        Color(red: 0.985, green: 0.980, blue: 0.955)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.cyan.opacity(effectiveScheme == .dark ? 0.13 : 0.10),
                    Color.clear,
                    Color.pink.opacity(effectiveScheme == .dark ? 0.10 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )

            CircuitGrid()
                .opacity(effectiveScheme == .dark ? 0.24 : 0.15)
        }
    }
}

struct EverclipHeaderMark: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(.cyan)
            .frame(width: 52, height: 52)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct CircuitGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 42
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(.primary.opacity(0.16)), lineWidth: 0.5)
        }
    }
}

extension View {
    func everclipPanel(cornerRadius: CGFloat = 22, borderOpacity: Double = 0.08, shadowOpacity: Double = 0.15) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 1, 0), style: .continuous)
                    .strokeBorder(Color.primary.opacity(borderOpacity), lineWidth: 1)
                    .padding(1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 22, x: 0, y: 14)
    }

    func everclipControl(cornerRadius: CGFloat = 14) -> some View {
        background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
