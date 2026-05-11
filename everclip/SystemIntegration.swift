//
//  SystemIntegration.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

#if os(macOS)
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import SwiftUI

@MainActor
final class EverclipModel: ObservableObject {
    let clipboard = ClipboardStore()
    let settings = AppSettings()

    private var hotKeyManager: GlobalHotKeyManager?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        settings.applyApplicationAppearance()
        settings.$theme
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.applyAppearanceToOpenSurfaces()
                }
            }
            .store(in: &cancellables)

        hotKeyManager = GlobalHotKeyManager { [weak self] in
            guard let self, self.settings.hotKeyEnabled else { return }
            FloatingClipboardPresenter.shared.show(store: self.clipboard, settings: self.settings)
        }

        Task { @MainActor [weak self] in
            guard let self, !self.settings.hasSeenIntro else { return }
            OnboardingWindowPresenter.shared.show(settings: self.settings, clipboard: self.clipboard)
        }
    }

    private func applyAppearanceToOpenSurfaces() {
        settings.applyApplicationAppearance()
        MainWindowPresenter.shared.applyAppearance(settings: settings)
        SettingsWindowPresenter.shared.applyAppearance(settings: settings)
        FloatingClipboardPresenter.shared.applyAppearance(settings: settings)
        OnboardingWindowPresenter.shared.applyAppearance(settings: settings)
    }
}

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func request() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        request()

        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL), NSWorkspace.shared.open(url) else { continue }
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
    }
}

final class GlobalHotKeyManager {
    private let action: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourCharacterCode("EVCP"), id: 1)

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        register()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                let manager = Unmanaged<GlobalHotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var receivedID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )

                guard parameterStatus == noErr, receivedID.id == manager.hotKeyID.id else {
                    return noErr
                }

                Task { @MainActor in
                    manager.action()
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else { return }

        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

@MainActor
final class FloatingClipboardPresenter {
    static let shared = FloatingClipboardPresenter()
    private static let panelSize = NSSize(width: 460, height: 410)
    private static let panelCornerRadius: CGFloat = 22

    private var panel: FloatingClipboardPanel?
    private weak var targetApplication: NSRunningApplication?
    private var targetFocusedElement: AXUIElement?

    func show(store: ClipboardStore, settings: AppSettings) {
        let ownBundleID = Bundle.main.bundleIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication

        if frontmost?.bundleIdentifier != ownBundleID {
            targetApplication = frontmost
            targetFocusedElement = focusedInputElement(for: frontmost)
        } else {
            targetApplication = nil
            targetFocusedElement = nil
        }

        let content = FloatingClipboardView(
            onPaste: { [weak self] item in
                guard let self else { return }
                let targetApplication = self.targetApplication
                let targetFocusedElement = self.targetFocusedElement

                self.panel?.makeFirstResponder(nil)
                self.panel?.resignKey()
                self.panel?.orderOut(nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    store.paste(
                        item,
                        performPaste: settings.pasteAfterSelection,
                        targetApplication: targetApplication,
                        focusedElement: targetFocusedElement
                    )
                }
            },
            onClose: { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        .environmentObject(store)
        .environmentObject(settings)
        .preferredColorScheme(settings.colorScheme)

        if panel == nil {
            let panel = FloatingClipboardPanel(
                contentRect: NSRect(origin: .zero, size: Self.panelSize),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )

            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.level = .floating
            panel.hidesOnDeactivate = false
            self.panel = panel
        }

        panel?.setContentSize(Self.panelSize)
        settings.applyAppearance(to: panel)
        panel?.installEverclipGlassContent(content, material: .popover, cornerRadius: Self.panelCornerRadius)
        configurePanelSurface()
        positionPanel(settings: settings)
        panel?.makeKeyAndOrderFront(nil)
    }

    func applyAppearance(settings: AppSettings) {
        settings.applyAppearance(to: panel)
    }

    private func positionPanel(settings: AppSettings) {
        guard let panel else { return }

        let size = panel.frame.size
        let anchor = focusedInputFrame(for: targetApplication)?.center ?? NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let visibleFrame = targetScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let origin: NSPoint
        if let focusedFrame = focusedInputFrame(for: targetApplication) {
            let x = min(max(focusedFrame.midX - size.width / 2, visibleFrame.minX + 18), visibleFrame.maxX - size.width - 18)
            let preferredY = focusedFrame.minY - size.height - 12
            let fallbackY = focusedFrame.maxY + 12
            let y = preferredY >= visibleFrame.minY + 18 ? preferredY : min(fallbackY, visibleFrame.maxY - size.height - 18)
            origin = NSPoint(x: x, y: max(y, visibleFrame.minY + 18))
        } else if settings.showFloatingNearPointer {
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(
                x: min(max(mouse.x - size.width / 2, visibleFrame.minX + 18), visibleFrame.maxX - size.width - 18),
                y: min(max(mouse.y - size.height - 16, visibleFrame.minY + 18), visibleFrame.maxY - size.height - 18)
            )
        } else {
            origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
        }

        panel.setFrameOrigin(origin)
    }

    private func configurePanelSurface() {
        guard let panel, let contentView = panel.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = Self.panelCornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func focusedInputElement(for application: NSRunningApplication?) -> AXUIElement? {
        guard AccessibilityPermission.isTrusted, let application else { return nil }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue
        else {
            return nil
        }

        return (focusedValue as! AXUIElement)
    }

    private func focusedInputFrame(for application: NSRunningApplication?) -> CGRect? {
        guard AccessibilityPermission.isTrusted, let application else { return nil }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue
        else {
            return nil
        }

        let element = focusedElement as! AXUIElement
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue
        else {
            return nil
        }

        let positionAXValue = positionValue as! AXValue
        let sizeAXValue = sizeValue as! AXValue

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size),
              size.width > 0,
              size.height > 0
        else {
            return nil
        }

        let displayMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let convertedY = displayMaxY - position.y - size.height
        return CGRect(x: position.x, y: convertedY, width: size.width, height: size.height)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

extension NSWindow {
    func configureEverclipGlassSurface(hasShadow: Bool = true) {
        isOpaque = false
        backgroundColor = .clear
        self.hasShadow = hasShadow
    }

    func installEverclipGlassContent<Content: View>(
        _ rootView: Content,
        material: NSVisualEffectView.Material = .underWindowBackground,
        cornerRadius: CGFloat? = nil
    ) {
        contentViewController = EverclipGlassHostingController(
            rootView: rootView,
            material: material,
            cornerRadius: cornerRadius
        )
    }
}

final class FloatingClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class EverclipGlassHostingController<Content: View>: NSViewController {
    private let hostingController: NSHostingController<Content>
    private let material: NSVisualEffectView.Material
    private let cornerRadius: CGFloat?

    init(rootView: Content, material: NSVisualEffectView.Material, cornerRadius: CGFloat?) {
        hostingController = NSHostingController(rootView: rootView)
        self.material = material
        self.cornerRadius = cornerRadius
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let glassView = NSVisualEffectView()
        glassView.material = material
        glassView.blendingMode = .behindWindow
        glassView.state = .active
        glassView.isEmphasized = true
        glassView.wantsLayer = true
        glassView.layer?.backgroundColor = NSColor.clear.cgColor

        if let cornerRadius {
            glassView.layer?.cornerRadius = cornerRadius
            glassView.layer?.cornerCurve = .continuous
            glassView.layer?.masksToBounds = true
        }

        let hostedView = hostingController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.wantsLayer = true
        hostedView.layer?.backgroundColor = NSColor.clear.cgColor
        hostedView.layer?.isOpaque = false

        view = glassView
        addChild(hostingController)
        glassView.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: glassView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
        ])
    }
}

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    func show(settings: AppSettings, clipboard: ClipboardStore) {
        if let window {
            settings.applyAppearance(to: window)
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView()
            .environmentObject(settings)
            .environmentObject(clipboard)
            .preferredColorScheme(settings.colorScheme)
            .frame(width: 560, height: 620)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Everclip 设置"
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

@MainActor
final class OnboardingWindowPresenter {
    static let shared = OnboardingWindowPresenter()

    private var window: NSWindow?

    func show(settings: AppSettings, clipboard: ClipboardStore) {
        if let window {
            settings.applyAppearance(to: window)
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = OnboardingView(
            onFinish: { [weak self] in
                settings.markIntroSeen()
                self?.window?.close()
            },
            onOpenSettings: {
                SettingsWindowPresenter.shared.show(settings: settings, clipboard: clipboard)
            }
        )
        .environmentObject(settings)
        .preferredColorScheme(settings.colorScheme)
        .frame(width: 560, height: 610)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 610),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "欢迎使用 Everclip"
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

private func fourCharacterCode(_ text: String) -> OSType {
    text.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}
#endif
