import SwiftUI
import MeteorDDPKit

struct PhotoDetailView: View {
    let photo: DashboardViewModel.Photo
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isSubmitting = false

    private let meteor = MeteorService.shared

    struct Comment: Identifiable {
        let id: String
        let authorName: String
        let text: String
        let createdAt: Date
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                photoImage

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let authorName = photo.authorName {
                            Label(authorName, systemImage: "person.fill")
                                .font(.argoBody)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(photo.createdAt.shortDateString)
                            .font(.argoCaption)
                            .foregroundStyle(.secondary)
                    }

                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption).font(.argoBody)
                    }

                    likeSection

                    Divider()

                    commentsSection

                    commentInput
                }
                .padding(.horizontal)
            }
        }
        .background(ArgoTheme.groupedBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadReactions() }
    }

    private var photoImage: some View {
        AsyncImage(url: URL(string: photo.imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            default:
                Rectangle().fill(ArgoTheme.tertiaryFill)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    private var likeSection: some View {
        HStack(spacing: 16) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .secondary)
                    if likeCount > 0 {
                        Text("\(likeCount)")
                            .font(.argoBody)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Label("\(comments.count)", systemImage: "bubble.right")
                .font(.argoBody)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if comments.isEmpty {
                Text("Nog geen reacties")
                    .font(.argoCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comment.authorName)
                                .font(.argoBody)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(comment.createdAt.shortDateString)
                                .font(.argoCaption)
                                .foregroundStyle(.secondary)
                        }
                        Text(comment.text)
                            .font(.argoBody)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var commentInput: some View {
        HStack(spacing: 8) {
            TextField("Schrijf een reactie...", text: $newComment)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await submitComment() }
            } label: {
                if isSubmitting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                }
            }
            .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
        }
        .padding(.bottom, 16)
    }

    private func loadReactions() async {
        guard let _ = try? await meteor.call("eventPhotos.feed", params: [1]) as? [[String: Any]] else { return }

        if let col = meteor.collection("photo_reactions") {
            let reactions = Array(col.documents.values).filter { ($0["photoId"] as? String) == photo.id }
            let userId = meteor.userId ?? ""

            likeCount = reactions.filter { ($0["type"] as? String) == "like" }.count
            isLiked = reactions.contains { ($0["type"] as? String) == "like" && ($0["userId"] as? String) == userId }

            comments = reactions
                .filter { ($0["type"] as? String) == "comment" }
                .compactMap { doc -> Comment? in
                    guard let id = doc["_id"] as? String, let text = doc["text"] as? String,
                          let createdAt = doc["createdAt"] as? Date else { return nil }
                    return Comment(id: id, authorName: doc["authorName"] as? String ?? "Lid", text: text, createdAt: createdAt)
                }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    private func toggleLike() async {
        _ = try? await meteor.call("eventPhotos.react", params: [photo.id, "like"])
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
    }

    private func submitComment() async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSubmitting = true
        _ = try? await meteor.call("eventPhotos.addComment", params: [photo.id, text])
        newComment = ""
        await loadReactions()
        isSubmitting = false
    }
}
