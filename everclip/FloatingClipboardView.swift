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

    private var results: [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = trimmed.isEmpty
            ? clipboard.displayItems
            : clipboard.displayItems.filter {
                $0.text.localizedCaseInsensitiveContains(trimmed) ||
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.kind.localizedCaseInsensitiveContains(trimmed)
            }

        return Array(items.prefix(9))
    }

    var body: some View {
        ZStack {
            StaticBackdrop(forcedScheme: settings.colorScheme)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    EverclipHeaderMark(systemName: "command.square.fill")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("快速粘贴")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))

                        Text(settings.pasteAfterSelection ? "选择后粘贴" : "选择后复制")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(settings.shortcutLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.07), in: Capsule())

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help("关闭")
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("搜索剪贴历史", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit {
                            pasteSelected()
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .everclipControl(cornerRadius: 14)

                if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("没有可粘贴内容")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                    FloatingClipRow(
                                        item: item,
                                        index: index + 1,
                                        isSelected: index == selectedIndex
                                    )
                                    .id(item.id)
                                    .onTapGesture {
                                        selectedIndex = index
                                        pasteSelected()
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
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
            .padding(22)
        }
        .frame(width: 560, height: 500)
        .everclipPanel(cornerRadius: 26, borderOpacity: 0, shadowOpacity: 0)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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

private struct FloatingClipRow: View {
    @EnvironmentObject private var clipboard: ClipboardStore
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            leadingPreview

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.kind)
                    Text(item.timestampText)
                    Text(item.metricText)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.accentColors.first ?? .cyan)
            }

            Image(systemName: "return")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .opacity(isSelected ? 1 : 0.45)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.10) : Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? (item.accentColors.first ?? .cyan).opacity(0.70) : Color.clear, lineWidth: 1)
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
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
    }

    @ViewBuilder
    private var leadingPreview: some View {
        if item.isImage, let image = item.nsImage {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.black.opacity(0.48), in: Circle())
                    .padding(3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            }
        } else {
            Text("\(index)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 26, height: 26)
                .background {
                    Circle()
                        .fill(isSelected ? item.accentColors.first ?? .cyan : Color.primary.opacity(0.07))
                }
        }
    }
}
#endif
