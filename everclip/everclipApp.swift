//
//  everclipApp.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct everclipApp: App {
    #if os(macOS)
    @StateObject private var model = EverclipModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @StateObject private var clipboard = ClipboardStore()
    @StateObject private var settings = AppSettings()
    #endif

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            MenuBarClipboardView()
                .environmentObject(model.clipboard)
                .environmentObject(model.settings)
        } label: {
            Image(systemName: "bolt.horizontal.circle.fill")
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView()
                .environmentObject(clipboard)
                .environmentObject(settings)
        }
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@MainActor
final class MainWindowPresenter {
    static let shared = MainWindowPresenter()

    private var window: NSWindow?

    func show(store: ClipboardStore, settings: AppSettings) {
        if let window {
            settings.applyAppearance(to: window)
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView()
            .environmentObject(store)
            .environmentObject(settings)
            .preferredColorScheme(settings.colorScheme)
            .frame(minWidth: 980, minHeight: 680)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Everclip"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.configureEverclipGlassSurface()
        settings.applyAppearance(to: window)
        window.center()
        window.installEverclipGlassContent(rootView, material: .underWindowBackground)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applyAppearance(settings: AppSettings) {
        settings.applyAppearance(to: window)
    }
}
#endif
