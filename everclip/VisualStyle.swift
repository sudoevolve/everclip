//
//  VisualStyle.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI
import Foundation

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

struct ClipActionRail: View {
    let isPinned: Bool
    let accentColors: [Color]
    var compact = false
    let pinAction: () -> Void
    let copyAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            HoverActionButton(
                systemName: isPinned ? "pin.slash.fill" : "pin.fill",
                helpText: isPinned ? "取消置顶" : "置顶收藏",
                tone: .accent,
                accentColors: accentColors,
                compact: compact,
                action: pinAction
            )

            HoverActionButton(
                systemName: "doc.on.clipboard",
                acknowledgedSystemName: "checkmark",
                helpText: "复制",
                tone: .neutral,
                accentColors: accentColors,
                compact: compact,
                action: copyAction
            )

            HoverActionButton(
                systemName: "trash.fill",
                helpText: "删除",
                tone: .destructive,
                accentColors: accentColors,
                compact: compact,
                action: deleteAction
            )
        }
        .padding(compact ? 4 : 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(compact ? 0.10 : 0.14), radius: compact ? 10 : 16, x: 0, y: compact ? 5 : 9)
    }
}

private enum HoverActionTone {
    case accent
    case neutral
    case destructive
}

private struct HoverActionButton: View {
    let systemName: String
    var acknowledgedSystemName: String?
    let helpText: String
    let tone: HoverActionTone
    let accentColors: [Color]
    let compact: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var feedbackTick = 0
    @State private var isAcknowledged = false

    private var width: CGFloat {
        switch tone {
        case .destructive:
            return compact ? 42 : 50
        case .accent, .neutral:
            return compact ? 32 : 38
        }
    }

    private var height: CGFloat {
        compact ? 30 : 36
    }

    var body: some View {
        Button(role: tone == .destructive ? .destructive : nil) {
            feedbackTick += 1

            if acknowledgedSystemName != nil {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.76)) {
                    isAcknowledged = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        isAcknowledged = false
                    }
                }
            }

            action()
        } label: {
            Image(systemName: isAcknowledged ? acknowledgedSystemName ?? systemName : systemName)
                .font(.system(size: compact ? 12 : 13, weight: .bold))
                .foregroundStyle(foregroundStyle)
                .frame(width: width, height: height)
                .background(buttonBackground)
                .overlay(buttonStroke)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous))
                .scaleEffect(isHovering ? 1.06 : 1)
                .rotationEffect(.degrees(tone == .destructive && isHovering ? -5 : 0))
                .symbolEffect(.bounce, value: feedbackTick)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.76)) {
                isHovering = hovering
            }
        }
    }

    private var foregroundStyle: Color {
        switch tone {
        case .accent:
            return accentColors.first ?? .cyan
        case .neutral:
            return isAcknowledged ? .green : .primary
        case .destructive:
            return .white
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch tone {
        case .accent:
            RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                .fill((accentColors.first ?? .cyan).opacity(isHovering ? 0.18 : 0.10))
        case .neutral:
            RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                .fill(Color.primary.opacity(isHovering || isAcknowledged ? 0.11 : 0.065))
        case .destructive:
            RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.20, blue: 0.26),
                            Color(red: 0.78, green: 0.05, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private var buttonStroke: some View {
        RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
            .strokeBorder(
                tone == .destructive ? Color.white.opacity(0.16) : Color.primary.opacity(isHovering ? 0.14 : 0.08),
                lineWidth: 1
            )
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
