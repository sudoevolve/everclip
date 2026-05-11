//
//  SettingsView.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var clipboard: ClipboardStore
    #if os(macOS)
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    #endif

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    EverclipHeaderMark(systemName: "slider.horizontal.3")

                    VStack(alignment: .leading, spacing: 5) {
                        Text("设置")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))

                        Text("Everclip")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(settings.shortcutLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                }
                .padding(14)
                .everclipPanel(cornerRadius: 24)

                VStack(spacing: 10) {
                    SettingsSection(title: "外观", systemImage: "circle.lefthalf.filled") {
                        Picker("模式", selection: themeBinding) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.title).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsSection(title: "快捷键", systemImage: "keyboard") {
                        Toggle("启用全局快捷键", isOn: $settings.hotKeyEnabled)

                        HStack {
                            Text("打开快速粘贴")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(settings.shortcutLabel)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.07), in: Capsule())
                        }
                    }

                    SettingsSection(title: "粘贴", systemImage: "text.cursor") {
                        Toggle("选择后自动粘贴", isOn: $settings.pasteAfterSelection)
                        Toggle("浮窗跟随指针", isOn: $settings.showFloatingNearPointer)

                        #if os(macOS)
                        HStack {
                            Label(
                                accessibilityTrusted ? "辅助功能已授权" : "需要辅助功能权限",
                                systemImage: accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(accessibilityTrusted ? .green : .orange)

                            Spacer()

                            Button(accessibilityTrusted ? "重新检测" : "打开系统设置") {
                                if !accessibilityTrusted {
                                    AccessibilityPermission.openSystemSettings()
                                }
                                refreshAccessibilityStatusSoon()
                            }
                        }
                        #endif
                    }

                    SettingsSection(title: "历史", systemImage: "clock.arrow.circlepath") {
                        HStack {
                            Text("\(clipboard.items.count) 条剪贴")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(role: .destructive) {
                                clipboard.clearHistory()
                            } label: {
                                Label("清空", systemImage: "trash")
                            }
                        }
                    }
                }

                Spacer(minLength: 6)

                SettingsFooter()
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(settings.colorScheme)
        #if os(macOS)
        .onAppear {
            refreshAccessibilityStatusSoon()
        }
        #endif
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { settings.theme },
            set: { newTheme in
                guard settings.theme != newTheme else { return }

                DispatchQueue.main.async {
                    settings.theme = newTheme
                }
            }
        )
    }

    #if os(macOS)
    private func refreshAccessibilityStatusSoon() {
        DispatchQueue.main.async {
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        let trusted = AccessibilityPermission.isTrusted
        guard accessibilityTrusted != trusted else { return }
        accessibilityTrusted = trusted
    }
    #endif
}

private struct SettingsFooter: View {
    var body: some View {
        HStack(spacing: 10) {
            Label("sudoevolve", systemImage: "person.crop.circle")

            Circle()
                .fill(Color.secondary.opacity(0.38))
                .frame(width: 4, height: 4)

            Link("sudoevolve@gmail.com", destination: URL(string: "mailto:sudoevolve@gmail.com")!)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            content
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .everclipPanel(cornerRadius: 18)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings())
            .environmentObject(ClipboardStore(previewItems: ClipboardItem.sampleItems))
            .frame(width: 560, height: 620)
    }
}
