import SwiftUI
import PhotosUI

struct TitleBlockView: View {
    @Binding var block: EditableBlock

    var body: some View {
        TextField("Geef je artikel een titel...", text: $block.textContent, axis: .vertical)
            .font(ArgoTheme.font(size: 24, weight: .bold))
            .foregroundStyle(ArgoTheme.editorTitle)
            .lineLimit(1...4)
    }
}

struct ParagraphBlockView: View {
    @Binding var block: EditableBlock

    var body: some View {
        TextEditor(text: $block.textContent)
            .font(ArgoTheme.font(size: 15))
            .frame(minHeight: 80)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                if block.textContent.isEmpty {
                    Text("Schrijf hier je tekst...")
                        .font(ArgoTheme.font(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct HeadingBlockView: View {
    @Binding var block: EditableBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Niveau", selection: $block.headingLevel) {
                Text("H2").tag(2)
                Text("H3").tag(3)
            }
            .pickerStyle(.segmented)
            .tint(ArgoTheme.interactiveAccent)
            .frame(width: 120)

            TextField("Heading...", text: $block.textContent, axis: .vertical)
                .font(ArgoTheme.font(size: block.headingLevel == 2 ? 20 : 17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1...3)
        }
    }
}

struct ImageBlockView: View {
    @Binding var block: EditableBlock
    var onPickImage: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let localImage = block.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let urlString = block.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        imagePlaceholder
                    }
                }
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button(action: onPickImage) {
                    imagePlaceholder
                }
            }

            TextField("Bijschrift...", text: $block.imageCaption)
                .font(ArgoTheme.font(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(height: 160)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(ArgoTheme.font(size: 28))
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                    Text("Kies een foto")
                        .font(ArgoTheme.font(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
    }
}

struct SeparatorBlockView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

struct BlockWrapperView: View {
    @Binding var block: EditableBlock
    var onDelete: () -> Void
    var onPickImage: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                blockContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if block.type != .separator {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(ArgoTheme.font(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(ArgoTheme.font(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: ArgoTheme.cardShadow, radius: 2, y: 1)
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.type {
        case .title:
            TitleBlockView(block: $block)
        case .paragraph:
            ParagraphBlockView(block: $block)
        case .heading:
            HeadingBlockView(block: $block)
        case .image:
            ImageBlockView(block: $block, onPickImage: onPickImage)
        case .separator:
            SeparatorBlockView()
        }
    }
}
