//
//  ContentView.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @EnvironmentObject private var settings: AppSettings
    @Namespace private var selectionNamespace
    @State private var selectedID: ClipboardItem.ID?

    private var selectedItem: ClipboardItem? {
        if let selectedID, let item = clipboard.items.first(where: { $0.id == selectedID }) {
            return item
        }

        return clipboard.filteredItems.first
    }

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HeaderBar()

                HStack(alignment: .top, spacing: 18) {
                    ClipboardTimeline(
                        selectedID: $selectedID,
                        selectionNamespace: selectionNamespace
                    )
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 480)

                    DetailPanel(item: selectedItem)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
        }
        .preferredColorScheme(settings.colorScheme)
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            CaptureCore(pulse: clipboard.capturePulse, isMonitoring: clipboard.isMonitoring)

            VStack(alignment: .leading, spacing: 6) {
                Text("Everclip")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))

                Text(clipboard.isMonitoring ? "剪贴板捕获中" : "捕获已暂停")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 18)

            SearchField(text: $clipboard.searchText)
                .frame(width: 300)

            #if os(macOS)
            IconButton(systemName: "keyboard", helpText: "快速粘贴") {
                FloatingClipboardPresenter.shared.show(store: clipboard, settings: settings)
            }
            #endif

            IconButton(
                systemName: clipboard.isMonitoring ? "pause.fill" : "play.fill",
                helpText: clipboard.isMonitoring ? "暂停捕获" : "继续捕获"
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    clipboard.toggleMonitoring()
                }
            }

            IconButton(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill", helpText: "切换日间/夜间") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    settings.theme = colorScheme == .dark ? .day : .night
                }
            }

            #if os(macOS)
            IconButton(systemName: "gearshape.fill", helpText: "设置") {
                SettingsWindowPresenter.shared.show(settings: settings, clipboard: clipboard)
            }
            #endif

            IconButton(systemName: "arrow.clockwise", helpText: "读取当前剪贴板") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    clipboard.captureCurrentPasteboard()
                }
            }
        }
        .padding(18)
        .everclipPanel(cornerRadius: 24)
    }
}

private struct ClipboardTimeline: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @Binding var selectedID: ClipboardItem.ID?
    var selectionNamespace: Namespace.ID
    @State private var collapsedGroupIDs: Set<String> = []

    private var groups: [ClipGroup] {
        makeGroups(from: clipboard.filteredItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("历史")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text("\(clipboard.filteredItems.count) 条剪贴")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(clipboard.isMonitoring ? .cyan : .secondary)
                    .symbolEffect(.bounce, value: clipboard.capturePulse)
            }
            .padding(.horizontal, 2)

            if clipboard.filteredItems.isEmpty {
                EmptyTimelineView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(groups) { group in
                            ClipGroupHeader(
                                title: group.title,
                                count: group.items.count,
                                systemName: group.systemName,
                                isCollapsed: collapsedGroupIDs.contains(group.id)
                            ) {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                    if collapsedGroupIDs.contains(group.id) {
                                        collapsedGroupIDs.remove(group.id)
                                    } else {
                                        collapsedGroupIDs.insert(group.id)
                                    }
                                }
                            }

                            if !collapsedGroupIDs.contains(group.id) {
                                ForEach(group.items) { item in
                                    ClipRow(
                                        item: item,
                                        isSelected: selectedID == item.id || selectedID == nil && item.id == clipboard.filteredItems.first?.id,
                                        namespace: selectionNamespace
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                            selectedID = item.id
                                        }
                                    }
                                    .contextMenu {
                                        Button(item.isPinned ? "取消置顶" : "置顶收藏") {
                                            clipboard.togglePinned(item)
                                        }

                                        Button("复制") {
                                            clipboard.copy(item)
                                        }

                                        Button("删除", role: .destructive) {
                                            clipboard.remove(item)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .everclipPanel(cornerRadius: 24)
    }

    private func makeGroups(from items: [ClipboardItem]) -> [ClipGroup] {
        let calendar = Calendar.current
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }

        var groups: [ClipGroup] = []

        if !pinned.isEmpty {
            groups.append(ClipGroup(id: "pinned", title: "收藏置顶", systemName: "pin.fill", items: pinned))
        }

        let today = unpinned.filter { calendar.isDateInToday($0.createdAt) }
        if !today.isEmpty {
            groups.append(ClipGroup(id: "today", title: "今天", systemName: "sun.max", items: today))
        }

        let yesterday = unpinned.filter { calendar.isDateInYesterday($0.createdAt) }
        if !yesterday.isEmpty {
            groups.append(ClipGroup(id: "yesterday", title: "昨天", systemName: "moon", items: yesterday))
        }

        let earlier = unpinned.filter {
            !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt)
        }
        if !earlier.isEmpty {
            groups.append(ClipGroup(id: "earlier", title: "更早", systemName: "archivebox", items: earlier))
        }

        return groups
    }
}

private struct ClipGroup: Identifiable {
    let id: String
    let title: String
    let systemName: String
    let items: [ClipboardItem]
}

private struct ClipGroupHeader: View {
    let title: String
    let count: Int
    let systemName: String
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 16)

                Label(title, systemImage: systemName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct ClipRow: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @Environment(\.colorScheme) private var colorScheme

    let item: ClipboardItem
    let isSelected: Bool
    var namespace: Namespace.ID

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ClipThumbnail(item: item, isActive: isSelected, size: CGSize(width: 48, height: 48))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.kind)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(item.accentColors.first ?? .cyan)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: Capsule())

                    Text(item.timestampText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 4)

                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            clipboard.togglePinned(item)
                        }
                    } label: {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.isPinned ? (item.accentColors.first ?? .cyan) : Color.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(isHovering || isSelected ? 0.09 : 0.04), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "取消置顶" : "置顶收藏")

                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            clipboard.copy(item)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isHovering || isSelected ? Color.primary : Color.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(isHovering || isSelected ? 0.09 : 0.04), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("复制")

                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            clipboard.remove(item)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isHovering || isSelected ? .red : Color.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(isHovering || isSelected ? 0.09 : 0.04), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.metricText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.075 : 0.045))

                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.04))
                        .matchedGeometryEffect(id: "selectedClip", in: namespace)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: item.accentColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.1
                        )
                }
            }
        }
        .scaleEffect(isHovering ? 1.006 : 1)
        .shadow(color: (item.accentColors.first ?? .cyan).opacity(isSelected ? 0.16 : 0), radius: 16, x: 0, y: 8)
        .onHover { hovering in
            withAnimation(.spring(response: 0.20, dampingFraction: 0.86)) {
                isHovering = hovering
            }
        }
    }
}

private struct DetailPanel: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    let item: ClipboardItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("预览")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text(item?.kind ?? "等待剪贴")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let item {
                    IconButton(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill", helpText: item.isPinned ? "取消置顶" : "置顶收藏") {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                            clipboard.togglePinned(item)
                        }
                    }

                    IconButton(systemName: "doc.on.doc", helpText: "复制此剪贴") {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                            clipboard.copy(item)
                        }
                    }

                    IconButton(systemName: "trash.fill", helpText: "删除此剪贴", role: .destructive) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                            clipboard.remove(item)
                        }
                    }
                }
            }

            if let item {
                HStack(spacing: 10) {
                    ForEach(item.accentColors.indices, id: \.self) { index in
                        Circle()
                            .fill(item.accentColors[index])
                            .frame(width: 10, height: 10)
                    }

                    Text(item.timestampText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(item.metricText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                ClipPreview(item: item)
            } else {
                EmptyDetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .everclipPanel(cornerRadius: 24)
    }
}

#if os(macOS)
struct MenuBarClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    CaptureCore(pulse: clipboard.capturePulse, isMonitoring: clipboard.isMonitoring)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Everclip")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))

                        Text(clipboard.isMonitoring ? "托盘捕获中" : "托盘已暂停")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    IconButton(
                        systemName: clipboard.isMonitoring ? "pause.fill" : "play.fill",
                        helpText: clipboard.isMonitoring ? "暂停捕获" : "继续捕获"
                    ) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            clipboard.toggleMonitoring()
                        }
                    }
                }

                SearchField(text: $clipboard.searchText)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if clipboard.filteredItems.isEmpty {
                            EmptyTimelineView()
                                .frame(height: 220)
                        } else {
                            ForEach(clipboard.filteredItems.prefix(8)) { item in
                                MenuClipRow(item: item)
                            }
                        }
                    }
                }
                .frame(height: 320)

                HStack(spacing: 10) {
                    Button {
                        FloatingClipboardPresenter.shared.show(store: clipboard, settings: settings)
                    } label: {
                        Image(systemName: "keyboard")
                            .frame(width: 38)
                    }
                    .controlSize(.large)
                    .help("快速粘贴")

                    Button {
                        MainWindowPresenter.shared.show(store: clipboard, settings: settings)
                    } label: {
                        Label("主窗口", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        SettingsWindowPresenter.shared.show(settings: settings, clipboard: clipboard)
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(width: 38)
                    }
                    .controlSize(.large)
                    .help("设置")

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .frame(width: 38)
                    }
                    .controlSize(.large)
                    .help("退出 Everclip")
                }
            }
            .padding(16)
        }
        .frame(width: 390, height: 530)
        .preferredColorScheme(settings.colorScheme)
    }
}

private struct MenuClipRow: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        Button {
            clipboard.copy(item)
        } label: {
            HStack(spacing: 12) {
                ClipThumbnail(item: item, isActive: false, size: CGSize(width: 38, height: 38))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(item.accentColors.first ?? .cyan)
                        }

                        Text(item.kind)
                        Text(item.timestampText)
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)
            }
            .padding(11)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(item.isPinned ? "取消置顶" : "置顶收藏") {
                clipboard.togglePinned(item)
            }

            Button("复制") {
                clipboard.copy(item)
            }

            Button("删除", role: .destructive) {
                clipboard.remove(item)
            }
        }
    }
}
#endif

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("搜索剪贴历史", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .everclipControl(cornerRadius: 14)
    }
}

private struct IconButton: View {
    let systemName: String
    let helpText: String
    var role: ButtonRole?
    let action: () -> Void

    init(systemName: String, helpText: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.systemName = systemName
        self.helpText = helpText
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(role == .destructive ? .red : Color.primary)
                .frame(width: 42, height: 42)
                .everclipControl(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

private struct CaptureCore: View {
    let pulse: Int
    let isMonitoring: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isMonitoring ? Color.cyan.opacity(0.16) : Color.secondary.opacity(0.12))

            Circle()
                .strokeBorder(isMonitoring ? Color.cyan.opacity(0.80) : Color.secondary.opacity(0.50), lineWidth: 2.5)

            Image(systemName: isMonitoring ? "bolt.horizontal.fill" : "pause.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isMonitoring ? .cyan : .secondary)
                .symbolEffect(.bounce, value: pulse)
        }
        .frame(width: 68, height: 68)
    }
}

private struct ClipPreview: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            #if os(macOS)
            if item.isImage, let image = item.nsImage {
                VStack(spacing: 12) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(18)

                    Text(item.imageDescription)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
            } else {
                textPreview
            }
            #else
            textPreview
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private var textPreview: some View {
        ScrollView {
            Text(item.preview)
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
        }
    }
}

private struct ClipPrism: View {
    let colors: [Color]
    let isActive: Bool
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: (colors.first ?? .cyan).opacity(isActive ? 0.28 : 0.12), radius: isActive ? 14 : 8)

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct ClipThumbnail: View {
    let item: ClipboardItem
    let isActive: Bool
    let size: CGSize

    var body: some View {
        #if os(macOS)
        if item.isImage, let image = item.nsImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(isActive ? 0.22 : 0.10), lineWidth: 1)
                }
                .shadow(color: (item.accentColors.first ?? .cyan).opacity(isActive ? 0.20 : 0.08), radius: isActive ? 14 : 8)
        } else {
            ClipPrism(colors: item.accentColors, isActive: isActive, systemName: item.isImage ? "photo" : "doc.text.viewfinder")
                .frame(width: size.width, height: size.height)
        }
        #else
        ClipPrism(colors: item.accentColors, isActive: isActive, systemName: item.isImage ? "photo" : "doc.text.viewfinder")
            .frame(width: size.width, height: size.height)
        #endif
    }
}

private struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("还没有剪贴")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text("复制文字后会自动出现在这里")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(.secondary)

            Text("等待内容")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ClipboardStore(previewItems: ClipboardItem.sampleItems))
            .environmentObject(AppSettings())
            .frame(width: 1080, height: 720)
    }
}
