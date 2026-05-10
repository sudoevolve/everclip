//
//  FloatingClipboardView.swift
//  everclip
//
//  Created by sudoevolve on 2026/5/10.
//

#if os(macOS)
import SwiftUI

struct FloatingClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    @EnvironmentObject private var settings: AppSettings
    @FocusState private var searchFocused: Bool

    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var closeHovering = false

    private var results: [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = trimmed.isEmpty
            ? clipboard.displayItems
            : clipboard.displayItems.filter {
                $0.text.localizedCaseInsensitiveContains(trimmed) ||
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.kind.localizedCaseInsensitiveContains(trimmed)
            }

        return Array(items.prefix(7))
    }

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    FloatingHeaderMark()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("快速粘贴")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))

                        Text(settings.pasteAfterSelection ? "选择后粘贴" : "选择后复制")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(settings.shortcutLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.07), in: Capsule())

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(closeHovering ? .white : .secondary)
                            .frame(width: 28, height: 28)
                            .background(closeHovering ? Color.red.opacity(0.90) : Color.primary.opacity(0.055), in: Circle())
                            .rotationEffect(.degrees(closeHovering ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                    .help("关闭")
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.74)) {
                            closeHovering = hovering
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("搜索剪贴历史", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .focused($searchFocused)
                        .onSubmit {
                            pasteSelected()
                        }

                    if !query.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.20, dampingFraction: 0.82)) {
                                query = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清除搜索")
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.primary.opacity(searchFocused ? 0.085 : 0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder((searchFocused ? Color.cyan : Color.primary).opacity(searchFocused ? 0.28 : 0.08), lineWidth: 1)
                }
                .animation(.spring(response: 0.22, dampingFraction: 0.84), value: searchFocused)

                if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("没有可粘贴内容")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 7) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                    FloatingClipRow(
                                        item: item,
                                        index: index + 1,
                                        isSelected: index == selectedIndex,
                                        onSelect: {
                                            selectedIndex = index
                                            pasteSelected()
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal, 1)
                            .padding(.vertical, 1)
                        }
                        .onChange(of: selectedIndex) { _, newValue in
                            guard results.indices.contains(newValue) else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                proxy.scrollTo(results[newValue].id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 460, height: 410)
        .everclipPanel(cornerRadius: 22, borderOpacity: 0, shadowOpacity: 0)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .preferredColorScheme(settings.colorScheme)
        .onAppear {
            selectedIndex = 0
            searchFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    private func pasteSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        let item = results[selectedIndex]
        searchFocused = false

        DispatchQueue.main.async {
            onPaste(item)
        }
    }
}

private struct FloatingHeaderMark: View {
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "command.square.fill")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.cyan)
            .frame(width: 40, height: 40)
            .background(Color.primary.opacity(isHovering ? 0.085 : 0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovering ? 0.14 : 0.08), lineWidth: 1)
            }
            .scaleEffect(isHovering ? 1.04 : 1)
            .onHover { hovering in
                withAnimation(.spring(response: 0.18, dampingFraction: 0.78)) {
                    isHovering = hovering
                }
            }
    }
}

private struct FloatingClipRow: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovering = false

    private var showsActions: Bool {
        isHovering
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            rowContent
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .padding(.trailing, showsActions ? 124 : 0)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture(perform: onSelect)

            if showsActions {
                ClipActionRail(
                    isPinned: item.isPinned,
                    accentColors: item.accentColors,
                    compact: true,
                    pinAction: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.80)) {
                            clipboard.togglePinned(item)
                        }
                    },
                    copyAction: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.80)) {
                            clipboard.copy(item)
                        }
                    },
                    deleteAction: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            clipboard.remove(item)
                        }
                    }
                )
                .padding(.trailing, 6)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.10) : Color.primary.opacity(isHovering ? 0.070 : 0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? (item.accentColors.first ?? .cyan).opacity(0.70) : Color.clear, lineWidth: 1)
        }
        .scaleEffect(isHovering ? 1.006 : 1)
        .shadow(color: (item.accentColors.first ?? .cyan).opacity(isSelected ? 0.10 : isHovering ? 0.08 : 0), radius: isHovering ? 10 : 7, x: 0, y: 5)
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
        .onHover { hovering in
            withAnimation(.spring(response: 0.20, dampingFraction: 0.82)) {
                isHovering = hovering
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
        .animation(.spring(response: 0.22, dampingFraction: 0.84), value: showsActions)
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            leadingPreview

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(item.kind)
                    Text(item.timestampText)
                    Text(item.metricText)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.accentColors.first ?? .cyan)
            }

            if !showsActions {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .opacity(isSelected ? 1 : 0.45)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var leadingPreview: some View {
        if item.isImage, let image = item.thumbnailImage {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(.black.opacity(0.48), in: Circle())
                    .padding(3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            }
        } else {
            Text("\(index)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(isSelected ? item.accentColors.first ?? .cyan : Color.primary.opacity(0.07))
                }
                .scaleEffect(isSelected ? 1.08 : 1)
        }
    }
}
#endif
