//
//  ClipboardStore.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI
import Combine

#if os(macOS)
import AppKit
import ApplicationServices
import Carbon.HIToolbox
#elseif canImport(UIKit)
import UIKit
#endif

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let imageData: Data?
    let imageWidth: Double?
    let imageHeight: Double?
    let createdAt: Date
    let accentIndex: Int
    let isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        imageData: Data? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        createdAt: Date = .now,
        accentIndex: Int? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.createdAt = createdAt
        let seed = imageData.map { "\($0.count)-\($0.stableFingerprint)" } ?? text
        self.accentIndex = accentIndex ?? abs(seed.hashValue % ClipboardItem.accentPairs.count)
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case imageData
        case imageWidth
        case imageHeight
        case createdAt
        case accentIndex
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        accentIndex = try container.decode(Int.self, forKey: .accentIndex)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    #if os(macOS)
    init?(image: NSImage, createdAt: Date = .now) {
        guard let data = Self.pngData(from: image) ?? image.tiffRepresentation else { return nil }

        self.init(
            text: "",
            imageData: data,
            imageWidth: image.size.width,
            imageHeight: image.size.height,
            createdAt: createdAt
        )
    }

    init?(imageData: Data, createdAt: Date = .now) {
        guard let image = NSImage(data: imageData) else { return nil }
        let data = Self.pngData(from: image) ?? imageData

        self.init(
            text: "",
            imageData: data,
            imageWidth: image.size.width,
            imageHeight: image.size.height,
            createdAt: createdAt
        )
    }
    #endif

    var isImage: Bool {
        imageData != nil
    }

    var title: String {
        if isImage {
            return "图片剪贴"
        }

        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else { return "空白剪贴" }
        return String(compact.prefix(54))
    }

    var preview: String {
        if isImage {
            return imageDescription
        }

        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")

        return cleaned.isEmpty ? "剪贴板内容为空" : cleaned
    }

    var kind: String {
        if isImage {
            return "图片"
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if URL(string: trimmed)?.scheme != nil {
            return "链接"
        }

        if trimmed.contains("{") && trimmed.contains("}") {
            return "结构"
        }

        if trimmed.contains("\n") {
            return "文本块"
        }

        return trimmed.count < 28 ? "片段" : "文本"
    }

    var characterCount: Int {
        if let imageData {
            return imageData.count
        }

        return text.count
    }

    var metricText: String {
        if isImage {
            return imageDescription
        }

        return "\(characterCount) 字符"
    }

    var signature: String {
        if let imageData {
            return "image:\(imageData.count):\(imageData.stableFingerprint)"
        }

        return "text:\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private var signatureSeed: String {
        if let imageData {
            return "\(imageData.count)-\(imageData.stableFingerprint)"
        }

        return text
    }

    var imageDescription: String {
        guard let imageData else { return "图片" }

        let sizeText: String
        if let imageWidth, let imageHeight {
            sizeText = "\(Int(imageWidth)) x \(Int(imageHeight))"
        } else {
            sizeText = "未知尺寸"
        }

        return "\(sizeText) · \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))"
    }

    var accentColors: [Color] {
        ClipboardItem.accentPairs[accentIndex % ClipboardItem.accentPairs.count]
    }

    func pinned(_ pinned: Bool) -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: text,
            imageData: imageData,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            createdAt: createdAt,
            accentIndex: accentIndex,
            isPinned: pinned
        )
    }

    #if os(macOS)
    var nsImage: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }

    static func pngData(from image: NSImage) -> Data? {
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = image.size
        return bitmap.representation(using: .png, properties: [:])
    }
    #endif

    static let accentPairs: [[Color]] = [
        [Color(red: 0.10, green: 0.90, blue: 0.96), Color(red: 0.29, green: 0.45, blue: 1.00)],
        [Color(red: 1.00, green: 0.36, blue: 0.72), Color(red: 0.57, green: 0.32, blue: 1.00)],
        [Color(red: 0.42, green: 1.00, blue: 0.57), Color(red: 0.00, green: 0.70, blue: 0.88)],
        [Color(red: 1.00, green: 0.82, blue: 0.27), Color(red: 1.00, green: 0.42, blue: 0.20)],
        [Color(red: 0.72, green: 0.96, blue: 1.00), Color(red: 0.81, green: 0.45, blue: 1.00)]
    ]

    static let sampleItems: [ClipboardItem] = [
        ClipboardItem(text: "Everclip 把 macOS 剪贴板变成可搜索、可回放、可驻留的灵感缓存。"),
        ClipboardItem(text: "https://developer.apple.com/design/human-interface-guidelines"),
        ClipboardItem(text: """
        struct MotionToken {
            let glow: Double
            let velocity: Double
            let tension: Double
        }
        """)
    ]
}

private extension Data {
    var stableFingerprint: UInt64 {
        reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* UInt64(1_099_511_628_211)
        }
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var searchText = ""
    @Published private(set) var capturePulse = 0
    @Published private(set) var isMonitoring = true

    private let maxItems = 80
    private let storageKey = "everclip.clipboard.history.v1"
    private var timer: Timer?

    #if os(macOS)
    private var lastChangeCount = NSPasteboard.general.changeCount
    #endif

    init(previewItems: [ClipboardItem]? = nil) {
        if let previewItems {
            items = previewItems
            isMonitoring = false
            return
        }

        restoreHistory()
        startMonitoring()
        captureCurrentPasteboard()
    }

    var displayItems: [ClipboardItem] {
        sortedItems(items)
    }

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return displayItems
        }

        let filtered = items.filter { item in
            item.text.localizedCaseInsensitiveContains(query) ||
            item.title.localizedCaseInsensitiveContains(query) ||
            item.kind.localizedCaseInsensitiveContains(query)
        }

        return sortedItems(filtered)
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        capturePulse += 1
    }

    func copy(_ item: ClipboardItem) {
        writeToSystemPasteboard(item)
        insertOrPromote(item, shouldPersist: true)
    }

    #if os(macOS)
    func paste(
        _ item: ClipboardItem,
        performPaste: Bool,
        targetApplication: NSRunningApplication?,
        focusedElement: AXUIElement?
    ) {
        copy(item)

        guard performPaste else { return }

        if !Self.isAccessibilityTrusted {
            Self.requestAccessibilityPermission()
        }

        Self.prepareTargetForPaste(targetApplication: targetApplication, focusedElement: focusedElement)

        let pasteDelay: TimeInterval = item.isImage ? 0.70 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            Self.prepareTargetForPaste(targetApplication: targetApplication, focusedElement: focusedElement)
            Self.postPasteShortcut()
        }
    }
    #endif

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistHistory()
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = items[index].pinned(!items[index].isPinned)
        capturePulse += 1
        persistHistory()
    }

    func clearHistory() {
        items.removeAll()
        persistHistory()
    }

    func captureCurrentPasteboard() {
        #if os(macOS)
        guard let item = readCurrentPasteboardItem() else { return }
        insertOrPromote(item, shouldPersist: true)
        #endif
    }

    private func startMonitoring() {
        #if os(macOS)
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.7, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.scanPasteboard()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        #endif
    }

    private func scanPasteboard() {
        #if os(macOS)
        guard isMonitoring else { return }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }

        lastChangeCount = pasteboard.changeCount

        guard let item = readCurrentPasteboardItem() else { return }
        insertOrPromote(item, shouldPersist: true)
        #endif
    }

    private func writeToSystemPasteboard(_ item: ClipboardItem) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.isImage {
            writeImageToPasteboard(item, pasteboard: pasteboard)
        } else {
            pasteboard.setString(item.text, forType: .string)
        }

        lastChangeCount = pasteboard.changeCount
        #elseif canImport(UIKit)
        UIPasteboard.general.string = item.text
        #endif
    }

    private func insertOrPromote(_ item: ClipboardItem, shouldPersist: Bool) {
        guard item.isImage || !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let wasPinned = items.first { $0.signature == item.signature }?.isPinned ?? item.isPinned
        let promotedItem = item.pinned(wasPinned)

        items.removeAll { $0.signature == item.signature }
        items.insert(promotedItem, at: 0)

        if items.count > maxItems {
            trimHistory()
        }

        capturePulse += 1

        if shouldPersist {
            persistHistory()
        }
    }

    private func trimHistory() {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        items = Array((pinned + unpinned).prefix(maxItems))
    }

    private func sortedItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }

            return first.createdAt > second.createdAt
        }
    }

    #if os(macOS)
    private func readCurrentPasteboardItem() -> ClipboardItem? {
        let pasteboard = NSPasteboard.general

        if let pngData = pasteboard.data(forType: .png),
           let item = ClipboardItem(imageData: pngData) {
            return item
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let item = ClipboardItem(imageData: tiffData) {
            return item
        }

        if let fileImage = imageFromCopiedFileURL(pasteboard),
           let item = ClipboardItem(image: fileImage) {
            return item
        }

        if let image = NSImage(pasteboard: pasteboard),
           let item = ClipboardItem(image: image) {
            return item
        }

        if let text = pasteboard.string(forType: .string) {
            return ClipboardItem(text: text)
        }

        return nil
    }

    private func writeImageToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        guard let image = item.nsImage else { return }

        let pngData = ClipboardItem.pngData(from: image)
        let tiffData = image.tiffRepresentation
        let fileURL = pngData.flatMap { exportedImageURL(for: item, pngData: $0) }
        var types: [NSPasteboard.PasteboardType] = []

        if pngData != nil {
            types.append(.png)
            types.append(.init("Apple PNG pasteboard type"))
        }

        if tiffData != nil {
            types.append(.tiff)
            types.append(.init("NeXT TIFF v4.0 pasteboard type"))
        }

        if fileURL != nil {
            types.append(.fileURL)
            types.append(.URL)
            types.append(.init("public.file-url"))
            types.append(.init("public.url"))
            types.append(.init("NSFilenamesPboardType"))
        }

        guard !types.isEmpty else {
            pasteboard.writeObjects([image])
            return
        }

        pasteboard.declareTypes(uniquePasteboardTypes(types), owner: nil)

        if let pngData {
            pasteboard.setData(pngData, forType: .png)
            pasteboard.setData(pngData, forType: .init("Apple PNG pasteboard type"))
        }

        if let tiffData {
            pasteboard.setData(tiffData, forType: .tiff)
            pasteboard.setData(tiffData, forType: .init("NeXT TIFF v4.0 pasteboard type"))
        }

        if let fileURL {
            pasteboard.setString(fileURL.absoluteString, forType: .fileURL)
            pasteboard.setString(fileURL.absoluteString, forType: .URL)
            pasteboard.setString(fileURL.absoluteString, forType: .init("public.file-url"))
            pasteboard.setString(fileURL.absoluteString, forType: .init("public.url"))
            pasteboard.setPropertyList([fileURL.path], forType: .init("NSFilenamesPboardType"))
        }
    }

    private func uniquePasteboardTypes(_ types: [NSPasteboard.PasteboardType]) -> [NSPasteboard.PasteboardType] {
        var seen: Set<String> = []
        return types.filter { type in
            seen.insert(type.rawValue).inserted
        }
    }

    private func exportedImageURL(for item: ClipboardItem, pngData: Data) -> URL? {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EverclipPasteboardImages", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fileURL = directoryURL.appendingPathComponent("\(item.id.uuidString).png")
            try pngData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private func imageFromCopiedFileURL(_ pasteboard: NSPasteboard) -> NSImage? {
        guard
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]
        else {
            return nil
        }

        return urls.lazy.compactMap { NSImage(contentsOf: $0) }.first
    }
    #endif

    private var historyFileURL: URL? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = appSupportURL.appendingPathComponent("Everclip", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("clipboard-history.json")
    }

    private func restoreHistory() {
        if let url = historyFileURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        guard let legacyData = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        defer {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }

        guard let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: legacyData) else {
            return
        }

        items = decoded
        persistHistoryToDisk(decoded)
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        persistHistoryToDiskData(data)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func persistHistoryToDisk(_ items: [ClipboardItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        persistHistoryToDiskData(data)
    }

    private func persistHistoryToDiskData(_ data: Data) {
        guard let url = historyFileURL else { return }
        try? data.write(to: url, options: .atomic)
    }

    #if os(macOS)
    private static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    private static func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func prepareTargetForPaste(targetApplication: NSRunningApplication?, focusedElement: AXUIElement?) {
        NSApplication.shared.deactivate()
        targetApplication?.activate(options: [.activateAllWindows])
        restoreFocus(to: focusedElement, targetApplication: targetApplication)
    }

    private static func restoreFocus(to focusedElement: AXUIElement?, targetApplication: NSRunningApplication?) {
        guard let focusedElement, let targetApplication else { return }

        let appElement = AXUIElementCreateApplication(targetApplication.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, focusedElement)
        AXUIElementSetAttributeValue(focusedElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private static func postPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandKey = CGKeyCode(kVK_Command)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: false)

        commandDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        commandUp?.flags = []

        commandDown?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            vDown?.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            vUp?.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.105) {
            commandUp?.post(tap: .cghidEventTap)
        }
    }
    #endif
}
