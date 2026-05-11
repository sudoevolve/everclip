//
//  AppSettings.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case day
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "跟随系统"
        case .day:
            return "日间"
        case .night:
            return "夜间"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .day:
            return .light
        case .night:
            return .dark
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(hotKeyEnabled, forKey: Keys.hotKeyEnabled) }
    }

    @Published var pasteAfterSelection: Bool {
        didSet { UserDefaults.standard.set(pasteAfterSelection, forKey: Keys.pasteAfterSelection) }
    }

    @Published var showFloatingNearPointer: Bool {
        didSet { UserDefaults.standard.set(showFloatingNearPointer, forKey: Keys.showFloatingNearPointer) }
    }

    @Published private(set) var hasSeenIntro: Bool {
        didSet { UserDefaults.standard.set(hasSeenIntro, forKey: Keys.hasSeenIntro) }
    }

    init() {
        let rawTheme = UserDefaults.standard.string(forKey: Keys.theme)
        theme = AppTheme(rawValue: rawTheme ?? "") ?? .system

        if UserDefaults.standard.object(forKey: Keys.hotKeyEnabled) == nil {
            hotKeyEnabled = true
        } else {
            hotKeyEnabled = UserDefaults.standard.bool(forKey: Keys.hotKeyEnabled)
        }

        if UserDefaults.standard.object(forKey: Keys.pasteAfterSelection) == nil {
            pasteAfterSelection = true
        } else {
            pasteAfterSelection = UserDefaults.standard.bool(forKey: Keys.pasteAfterSelection)
        }

        if UserDefaults.standard.object(forKey: Keys.showFloatingNearPointer) == nil {
            showFloatingNearPointer = true
        } else {
            showFloatingNearPointer = UserDefaults.standard.bool(forKey: Keys.showFloatingNearPointer)
        }

        hasSeenIntro = UserDefaults.standard.bool(forKey: Keys.hasSeenIntro)
        UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
    }

    var colorScheme: ColorScheme? {
        theme.colorScheme
    }

    #if os(macOS)
    var nsAppearance: NSAppearance? {
        switch theme {
        case .system:
            return nil
        case .day:
            return NSAppearance(named: .aqua)!
        case .night:
            return NSAppearance(named: .darkAqua)!
        }
    }

    func applyAppearance(to window: NSWindow?) {
        window?.appearance = nsAppearance
    }

    func applyApplicationAppearance() {
        NSApplication.shared.appearance = nsAppearance
    }
    #endif

    var shortcutLabel: String {
        "⌘⇧V"
    }

    var isNightMode: Bool {
        theme == .night
    }

    func isNightMode(systemColorScheme: ColorScheme) -> Bool {
        switch theme {
        case .system:
            return systemColorScheme == .dark
        case .day:
            return false
        case .night:
            return true
        }
    }

    func toggleTheme(systemColorScheme: ColorScheme) {
        switch theme {
        case .system:
            theme = systemColorScheme == .dark ? .day : .night
        case .day:
            theme = .night
        case .night:
            theme = .day
        }
    }

    func markIntroSeen() {
        hasSeenIntro = true
    }

    private enum Keys {
        static let theme = "everclip.settings.theme"
        static let hotKeyEnabled = "everclip.settings.hotKeyEnabled"
        static let pasteAfterSelection = "everclip.settings.pasteAfterSelection"
        static let showFloatingNearPointer = "everclip.settings.showFloatingNearPointer"
        static let hasSeenIntro = "everclip.settings.hasSeenIntro"
    }
}
