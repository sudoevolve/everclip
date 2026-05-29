//
//  OnboardingView.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI
#if os(macOS)
import Combine
#endif

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    let onFinish: () -> Void
    let onOpenSettings: () -> Void
    #if os(macOS)
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    #endif

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    EverclipHeaderMark(systemName: "bolt.horizontal.circle.fill")

                    VStack(alignment: .leading, spacing: 5) {
                        Text("欢迎使用 Everclip")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))

                        Text("剪贴板历史、快速粘贴和图片剪贴会在菜单栏里安静运行。")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .everclipPanel(cornerRadius: 24)

                VStack(spacing: 12) {
                    IntroRow(systemName: "menubar.rectangle", title: "菜单栏驻留", detail: "Everclip 不占 Dock，通过菜单栏打开历史、设置和快速粘贴。")
                    IntroRow(systemName: "keyboard", title: "快速粘贴", detail: "\(settings.shortcutLabel) 打开浮窗，用方向键选择，回车粘贴。")
                    IntroRow(systemName: "photo.on.rectangle", title: "文本和图片", detail: "复制文字、截图或图片都会进入历史，并可再次复制或粘贴。")
                    IntroRow(
                        systemName: "checkmark.shield",
                        title: "自动粘贴权限",
                        detail: permissionDetail
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        onOpenSettings()
                        #if os(macOS)
                        refreshAccessibilityStatusSoon()
                        #endif
                    } label: {
                        Label(primaryActionTitle, systemImage: primaryActionIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        onFinish()
                    } label: {
                        Label("开始使用", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    #if os(macOS)
                    .disabled(!accessibilityTrusted)
                    #endif
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 34)
        }
        .preferredColorScheme(settings.colorScheme)
        #if os(macOS)
        .onAppear {
            refreshAccessibilityStatusSoon()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatusSoon()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            refreshAccessibilityStatus()
        }
        #endif
    }

    private var permissionDetail: String {
        #if os(macOS)
        if accessibilityTrusted {
            return "辅助功能权限已授权，可以使用快捷键、回车粘贴和点击粘贴。"
        }

        return "必须先授予 macOS 辅助功能权限，Everclip 才能把内容自动粘贴到当前输入框。"
        #else
        return "自动回填到输入框需要系统权限。"
        #endif
    }

    private var primaryActionTitle: String {
        #if os(macOS)
        accessibilityTrusted ? "打开设置" : "授予权限"
        #else
        "打开设置"
        #endif
    }

    private var primaryActionIcon: String {
        #if os(macOS)
        accessibilityTrusted ? "gearshape" : "lock.open"
        #else
        "gearshape"
        #endif
    }

    #if os(macOS)
    private func refreshAccessibilityStatusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }
    #endif
}

private struct IntroRow: View {
    let systemName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .everclipPanel(cornerRadius: 18)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {}, onOpenSettings: {})
            .environmentObject(AppSettings())
            .frame(width: 560, height: 610)
    }
}
