import SwiftUI

struct BlogCard: View {
    let title: String
    let imageUrl: String?
    let authorName: String?
    let publishedAt: Date?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                backgroundImage
            }
            .overlay(alignment: .bottom) {
                gradientOverlay
            }
            .overlay(alignment: .bottomLeading) {
                textOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var backgroundImage: some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    fallbackBackground
                default:
                    fallbackBackground.overlay(ProgressView().tint(.white))
                }
            }
        } else {
            fallbackBackground
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.85), location: 0),
                .init(color: .black.opacity(0.5), location: 0.35),
                .init(color: .clear, location: 0.8)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var textOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let publishedAt {
                    Text(publishedAt.shortDateString)
                        .font(.argoCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                if let authorName {
                    Spacer()
                    authorBadge(authorName)
                }
            }
            Text(title)
                .font(ArgoTheme.font(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
    }

    private func authorBadge(_ name: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(ArgoTheme.blueNormal)
                    .frame(width: 22, height: 22)
                Text(String(name.prefix(1)).uppercased())
                    .font(ArgoTheme.font(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(name)
                .font(.argoCaption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var fallbackBackground: some View {
        Rectangle().fill(
            LinearGradient(colors: [ArgoTheme.blueDark, ArgoTheme.blueNormal],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

}
