import SwiftUI
import MeteorDDPKit
import AVKit
import WebKit

struct BlogPostDetailView: View {
    let postId: String
    @Environment(\.dismiss) private var dismiss

    @State private var post: BlogDetail?
    @State private var counts = ReactionCounts()
    @State private var activity: [ActivityItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var commentText = ""
    @State private var selectedEmoji: EmojiOption?
    @State private var isSubmitting = false
    @State private var isLikeLoading = false
    /// Voorkomt dubbele RPC bij `blog_reactions`-events wanneer de inhoud t.o.v. minimongo ongewijzigd is.
    @State private var lastReactionFingerprint: String = ""

    private let meteor = MeteorService.shared

    struct EmojiOption: Identifiable, Equatable {
        let id: String
        let sfSymbol: String
        let serverValue: String
    }

    private let emojiOptions: [EmojiOption] = [
        EmojiOption(id: "thumbsup", sfSymbol: "hand.thumbsup.fill", serverValue: "\u{1F44D}"),
        EmojiOption(id: "heart", sfSymbol: "heart.fill", serverValue: "\u{2764}\u{FE0F}"),
        EmojiOption(id: "laugh", sfSymbol: "face.smiling", serverValue: "\u{1F602}"),
        EmojiOption(id: "smile", sfSymbol: "sun.max.fill", serverValue: "\u{1F60A}"),
        EmojiOption(id: "party", sfSymbol: "party.popper.fill", serverValue: "\u{1F389}"),
    ]

    private static let emojiToSFSymbol: [String: String] = [
        "\u{1F44D}": "hand.thumbsup.fill",
        "\u{2764}\u{FE0F}": "heart.fill",
        "\u{1F602}": "face.smiling",
        "\u{1F60A}": "sun.max.fill",
        "\u{1F389}": "party.popper.fill",
    ]

    struct BlogDetail {
        let id: String
        let title: String
        let imageUrl: String?
        let authorName: String?
        let publishedAt: Date?
        let blocks: [[String: Any]]
        let viewCount: Int
    }

    struct ReactionCounts {
        var likes = 0
        var dislikes = 0
        var comments = 0
        var userSentiment: String? = nil
    }

    struct ActivityItem: Identifiable {
        let id: String
        let type: String
        let emoji: String?
        let text: String?
        let personName: String
        let date: String
    }

    var body: some View {
        ScrollView {
            if isLoading {
                LoadingView(message: "Artikel laden...")
                    .padding(.top, 60)
            } else if let post {
                VStack(alignment: .leading, spacing: 0) {
                    articleContent(post)
                    detailsCard(post)
                    reactionsSection
                    commentForm
                    activityTimeline
                    Spacer(minLength: 40)
                }
            } else {
                EmptyStateView(icon: "newspaper", title: errorMessage ?? "Artikel niet gevonden")
                    .padding(.top, 60)
            }
        }
        .background(ArgoTheme.groupedBackground)
        .ignoresSafeArea(.all, edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(ArgoTheme.font(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
            }
        }
        .task(id: postId) {
            await loadAll()
            await runReactionsLiveUpdatesWithCleanup()
        }
    }

    // MARK: - Artikel

    @ViewBuilder
    private func articleContent(_ post: BlogDetail) -> some View {
        if let imageUrl = post.imageUrl, let url = URLResolver.resolveURL(imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 300).clipped()
                default:
                    Rectangle().fill(ArgoTheme.tertiaryFill).frame(height: 300)
                }
            }
        }

        VStack(alignment: .leading, spacing: 16) {
            Text(post.title)
                .font(ArgoTheme.font(size: 24, weight: .bold))

            Divider()

            ForEach(Array(post.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .padding(16)
    }

    // MARK: - Details kaart

    private func detailsCard(_ post: BlogDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(ArgoTheme.font(size: 15, weight: .bold))

            if let authorName = post.authorName {
                detailRow(label: "Auteur") {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(ArgoTheme.blueNormal).frame(width: 26, height: 26)
                            Text(String(authorName.prefix(1)).uppercased())
                                .font(ArgoTheme.font(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(authorName).font(.argoBody)
                    }
                }
            }

            if let publishedAt = post.publishedAt {
                detailRow(label: "Gepubliceerd") {
                    Text(publishedAt.longDateString).font(.argoBody)
                }
            }

            HStack(spacing: 16) {
                Label("\(post.viewCount)", systemImage: "eye")
                Label("\(counts.likes)", systemImage: "hand.thumbsup")
                Label("\(counts.comments)", systemImage: "bubble.right")
            }
            .font(.argoCaption)
            .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button {
                    Task { await toggleLike("like") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: counts.userSentiment == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("Leuk")
                    }
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(counts.userSentiment == "like" ? ArgoTheme.interactiveAccent.opacity(0.18) : Color.clear)
                    .foregroundStyle(counts.userSentiment == "like" ? ArgoTheme.interactiveAccent : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLikeLoading)

                Button {
                    Task { await toggleLike("dislike") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: counts.userSentiment == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        Text("Niet leuk")
                    }
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(counts.userSentiment == "dislike" ? Color.red.opacity(0.15) : Color.clear)
                    .foregroundStyle(counts.userSentiment == "dislike" ? .red : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLikeLoading)

                Spacer()
            }
        }
        .padding(16)
        .background(ArgoTheme.secondaryGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Reacties header

    private var reactionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reacties")
                .font(ArgoTheme.font(size: 15, weight: .bold))
                .foregroundStyle(.primary)
            if activity.filter({ $0.type == "comment" }).isEmpty {
                Text("Nog geen reacties \u{2014} wees de eerste!")
                    .font(.argoCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Comment invoer

    private var commentForm: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                TextField("Schrijf een reactie...", text: $commentText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .font(.argoBody)

                Button {
                    Task { await submitComment() }
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Plaats")
                            .font(ArgoTheme.font(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(ArgoTheme.blueNormal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty && selectedEmoji == nil || isSubmitting)
            }

            HStack(spacing: 12) {
                ForEach(emojiOptions) { option in
                    Button {
                        selectedEmoji = selectedEmoji == option ? nil : option
                    } label: {
                        Image(systemName: option.sfSymbol)
                            .font(ArgoTheme.font(size: 20))
                            .foregroundStyle(selectedEmoji == option ? ArgoTheme.interactiveAccent : .secondary)
                            .frame(width: 36, height: 36)
                            .background(selectedEmoji == option ? ArgoTheme.interactiveAccent.opacity(0.22) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Activiteit tijdlijn

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(activity.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        timelineIcon(for: item)
                        if index < activity.count - 1 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 28)

                    if item.type == "comment" {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(item.personName)
                                    .font(ArgoTheme.font(size: 12, weight: .semibold))
                                Text("reageerde")
                                    .font(.argoCaption)
                                    .foregroundStyle(.secondary)
                                if let emoji = item.emoji, let sfSymbol = Self.emojiToSFSymbol[emoji] {
                                    Image(systemName: sfSymbol)
                                        .font(ArgoTheme.font(size: 14))
                                        .foregroundStyle(ArgoTheme.interactiveAccent)
                                } else if let emoji = item.emoji, !emoji.isEmpty {
                                    Image(systemName: "face.smiling")
                                        .font(ArgoTheme.font(size: 14))
                                        .foregroundStyle(ArgoTheme.interactiveAccent)
                                }
                                Spacer()
                                Text(item.date)
                                    .font(ArgoTheme.font(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            if let text = item.text, !text.isEmpty {
                                Text(text)
                                    .font(.argoBody)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 4) {
                            Text(item.personName)
                                .font(ArgoTheme.font(size: 12, weight: .semibold))
                            Text(item.type == "like" ? "vindt dit leuk" : "vindt dit niet leuk")
                                .font(.argoCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.date)
                                .font(ArgoTheme.font(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func timelineIcon(for item: ActivityItem) -> some View {
        ZStack {
            Circle()
                .fill(item.type == "comment" ? ArgoTheme.interactiveAccent.opacity(0.25) : (item.type == "like" ? ArgoTheme.interactiveAccent.opacity(0.25) : Color.red.opacity(0.15)))
                .frame(width: 28, height: 28)
            Group {
                switch item.type {
                case "comment":
                    Image(systemName: "bubble.right.fill")
                case "like":
                    Image(systemName: "hand.thumbsup.fill")
                case "dislike":
                    Image(systemName: "hand.thumbsdown.fill")
                default:
                    Image(systemName: "circle.fill")
                }
            }
            .font(ArgoTheme.font(size: 12))
            .foregroundStyle(item.type == "dislike" ? .red : ArgoTheme.interactiveAccent)
        }
    }

    // MARK: - Detail row helper

    private func detailRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.argoCaption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Blokken renderen

    @ViewBuilder
    private func blockView(_ block: [String: Any]) -> some View {
        let type = block["type"] as? String ?? ""
        let content = block["content"]

        switch type {
        case "paragraph":
            if let text = content as? String, !text.isEmpty {
                Text(text).font(.argoBody).lineSpacing(4)
            }
        case "heading":
            if let dict = content as? [String: Any], let text = dict["text"] as? String {
                let level = dict["level"] as? Int ?? 2
                Text(text)
                    .font(ArgoTheme.font(size: level <= 2 ? 20 : 17, weight: .bold))
                    .padding(.top, 4)
            }
        case "title":
            if let text = content as? String, !text.isEmpty {
                Text(text)
                    .font(ArgoTheme.font(size: 20, weight: .bold))
                    .padding(.top, 4)
            }
        case "quote":
            if let dict = content as? [String: Any], let text = dict["text"] as? String {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Rectangle().fill(ArgoTheme.blueNormal).frame(width: 3)
                        Text(text).font(.argoBody).italic().padding(.leading, 12)
                    }
                    if let citation = dict["citation"] as? String, !citation.isEmpty {
                        Text("\u{2014} \(citation)")
                            .font(.argoCaption).foregroundStyle(.secondary).padding(.leading, 15)
                    }
                }
            }
        case "list":
            if let dict = content as? [String: Any], let items = dict["items"] as? [String] {
                let style = dict["style"] as? String ?? "bullet"
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(style == "numbered" ? "\(index + 1)." : "\u{2022}")
                                .font(.argoBody).foregroundStyle(.secondary)
                            Text(item).font(.argoBody)
                        }
                    }
                }
            }
        case "image":
            if let dict = content as? [String: Any], let imgUrl = dict["url"] as? String,
               let url = URLResolver.resolveURL(imgUrl) {
                VStack(spacing: 4) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                        default:
                            Rectangle().fill(ArgoTheme.tertiaryFill).frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if let caption = dict["caption"] as? String, !caption.isEmpty {
                        Text(caption).font(.argoCaption).foregroundStyle(.secondary)
                    }
                }
            }
        case "video":
            if let dict = content as? [String: Any] {
                VStack(alignment: .leading, spacing: 4) {
                    if let raw = dict["url"] as? String, let abs = URLResolver.resolve(raw) {
                        if let embed = blogVideoEmbedURL(absoluteString: abs) {
                            BlogEmbedWebView(url: embed)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let browser = URL(string: abs) {
                            Link(destination: browser) {
                                Text("Video openen")
                                    .font(ArgoTheme.font(size: 14, weight: .semibold))
                                    .foregroundStyle(ArgoTheme.interactiveAccent)
                            }
                        }
                    }
                    if let caption = dict["caption"] as? String, !caption.isEmpty {
                        Text(caption).font(.argoCaption).foregroundStyle(.secondary)
                    }
                }
            }
        case "video_upload":
            if let dict = content as? [String: Any],
               let raw = dict["url"] as? String,
               let streamURL = URLResolver.resolveURL(raw) {
                VStack(alignment: .leading, spacing: 4) {
                    VideoPlayer(player: AVPlayer(url: streamURL))
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if let caption = dict["caption"] as? String, !caption.isEmpty {
                        Text(caption).font(.argoCaption).foregroundStyle(.secondary)
                    }
                }
            }
        case "code":
            if let dict = content as? [String: Any], let code = dict["code"] as? String, !code.isEmpty {
                let language = dict["language"] as? String
                VStack(alignment: .leading, spacing: 0) {
                    if let language, !language.isEmpty {
                        Text(language.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 12).padding(.top, 8)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                }
                .background(Color(white: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case "separator":
            Divider().padding(.vertical, 4)
        case "button":
            if let dict = content as? [String: Any], let text = dict["text"] as? String,
               let urlStr = dict["url"] as? String, let url = URL(string: urlStr) {
                Link(destination: url) {
                    Text(text).font(.argoSubheadline).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(ArgoTheme.blueNormal).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Live reacties (DDP `blog.reactionsPublished` + minimongo `blog_reactions`)

    private func reactionFingerprint() -> String {
        guard let col = meteor.collection("blog_reactions") else { return "" }
        return col.documents.values
            .filter { ($0["blogId"] as? String) == postId }
            .sorted { ($0["_id"] as? String ?? "") < ($1["_id"] as? String ?? "") }
            .map { doc in
                let id = doc["_id"] as? String ?? ""
                let type = doc["type"] as? String ?? ""
                let created: TimeInterval = {
                    if let d = doc["createdAt"] as? Date { return d.timeIntervalSince1970 }
                    if let t = doc["createdAt"] as? TimeInterval { return t }
                    return 0
                }()
                let emoji = doc["emoji"] as? String ?? ""
                let text = doc["text"] as? String ?? ""
                return "\(id):\(type):\(created):\(emoji):\(text)"
            }
            .joined(separator: "|")
    }

    private func runReactionsLiveUpdatesWithCleanup() async {
        guard post != nil else { return }
        var sub: DDPSubscription?
        defer {
            let toStop = sub
            Task { try? await toStop?.stop() }
        }
        do {
            sub = try await meteor.subscribe("blog.reactionsPublished", params: [postId])
            try await sub?.waitUntilReady()
        } catch {
            return
        }
        await MainActor.run { lastReactionFingerprint = reactionFingerprint() }
        guard let col = meteor.collection("blog_reactions") else { return }
        for await _ in col.events {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(200))
            let fp = reactionFingerprint()
            guard !fp.isEmpty else { continue }
            let shouldRefresh = await MainActor.run {
                if fp == lastReactionFingerprint { return false }
                lastReactionFingerprint = fp
                return true
            }
            if shouldRefresh {
                await loadCounts()
                await loadActivity()
            }
        }
    }

    // MARK: - API calls

    private func loadAll() async {
        isLoading = true
        await loadPost()
        async let c: () = loadCounts()
        async let a: () = loadActivity()
        _ = await (c, a)
        isLoading = false
    }

    private func loadPost() async {
        do {
            guard let result = try await meteor.call("blogs.getPublic", params: [postId]) as? [String: Any] else {
                errorMessage = "Artikel niet gevonden"
                return
            }
            let rawUrl = result["headerImageSquare"] as? String ?? result["headerImageUrl"] as? String
            let author = result["author"] as? [String: Any]
            post = BlogDetail(
                id: result["_id"] as? String ?? postId,
                title: result["headerTitle"] as? String ?? "",
                imageUrl: URLResolver.resolve(rawUrl),
                authorName: author?["name"] as? String,
                publishedAt: result["publishedAt"] as? Date,
                blocks: result["blocks"] as? [[String: Any]] ?? [],
                viewCount: result["viewCount"] as? Int ?? 0
            )
        } catch {
            errorMessage = "Kon artikel niet laden"
        }
    }

    private func loadCounts() async {
        guard let result = try? await meteor.call("blog.reactions.counts", params: [postId]) as? [String: Any] else { return }
        counts = ReactionCounts(
            likes: result["likes"] as? Int ?? 0,
            dislikes: result["dislikes"] as? Int ?? 0,
            comments: result["comments"] as? Int ?? 0,
            userSentiment: result["userSentiment"] as? String
        )
    }

    private func loadActivity() async {
        guard let result = try? await meteor.call("blog.reactions.list", params: [postId]) as? [[String: Any]] else { return }
        activity = result.compactMap { item -> ActivityItem? in
            guard let id = item["id"] as? String, let type = item["type"] as? String else { return nil }
            let person = item["person"] as? [String: Any]
            return ActivityItem(
                id: id, type: type,
                emoji: item["emoji"] as? String,
                text: item["text"] as? String,
                personName: person?["name"] as? String ?? "Onbekend",
                date: item["date"] as? String ?? ""
            )
        }
    }

    private func toggleLike(_ sentiment: String) async {
        isLikeLoading = true
        let newVal: Any = counts.userSentiment == sentiment ? NSNull() : sentiment
        _ = try? await meteor.call("blog.reactions.setLike", params: [postId, newVal])
        await loadCounts()
        await loadActivity()
        await MainActor.run { lastReactionFingerprint = reactionFingerprint() }
        isLikeLoading = false
    }

    private func submitComment() async {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || selectedEmoji != nil else { return }
        isSubmitting = true
        let payload: [String: Any?] = ["emoji": selectedEmoji?.serverValue, "text": text.isEmpty ? nil : text]
        _ = try? await meteor.call("blog.reactions.add", params: [postId, payload as Any])
        commentText = ""
        selectedEmoji = nil
        await loadCounts()
        await loadActivity()
        await MainActor.run { lastReactionFingerprint = reactionFingerprint() }
        isSubmitting = false
    }

}

// MARK: - Blog video (YouTube/Vimeo embed + geüploade MP4)

private func blogVideoEmbedURL(absoluteString: String) -> URL? {
    let s = absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.range(of: "youtube.com/embed/", options: .caseInsensitive) != nil {
        return URL(string: s)
    }
    if let range = s.range(of: "youtu.be/", options: .caseInsensitive) {
        var id = String(s[range.upperBound...])
        if let q = id.firstIndex(of: "?") { id = String(id[..<q]) }
        if let h = id.firstIndex(of: "#") { id = String(id[..<h]) }
        id = id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !id.isEmpty { return URL(string: "https://www.youtube.com/embed/\(id)") }
    }
    if s.localizedCaseInsensitiveContains("youtube.com/watch") {
        if let components = URLComponents(string: s),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !v.isEmpty {
            return URL(string: "https://www.youtube.com/embed/\(v)")
        }
        let replaced = s.replacingOccurrences(of: "watch?v=", with: "embed/")
        if replaced != s, let u = URL(string: replaced) { return u }
    }
    if s.range(of: "player.vimeo.com/video/", options: .caseInsensitive) != nil {
        return URL(string: s)
    }
    if s.localizedCaseInsensitiveContains("vimeo.com/"), let url = URL(string: s) {
        let parts = url.pathComponents.filter { $0 != "/" }
        if let id = parts.first, id.allSatisfy(\.isNumber) {
            return URL(string: "https://player.vimeo.com/video/\(id)")
        }
    }
    return nil
}

private struct BlogEmbedWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let w = WKWebView(frame: .zero, configuration: config)
        w.scrollView.isScrollEnabled = false
        w.load(URLRequest(url: url))
        return w
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

