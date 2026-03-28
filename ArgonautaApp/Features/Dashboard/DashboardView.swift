import SwiftUI

enum HomeRoute: Hashable {
    case photosAll
    case photoDetail(DashboardViewModel.Photo)
    case blogAll
    case blogDetail(String)
    case settings
}

struct DashboardView: View {
    @Environment(NotificationsViewModel.self) private var notifications
    @State private var viewModel = DashboardViewModel()
    @State private var showCamera = false
    @State private var showBlogEditor = false
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerBar

                    if !viewModel.announcements.isEmpty {
                        announcementsSection
                    }

                    photosSection

                    if !viewModel.recentPosts.isEmpty {
                        blogSection
                    }

                    Spacer(minLength: 20)
                }
            }
            .background(ArgoTheme.groupedBackground)
            .navigationBarHidden(true)
            .refreshable { await viewModel.loadData() }
            .task { await viewModel.loadData() }
            .onReceive(NotificationCenter.default.publisher(for: .meteorConnectionRestored)) { _ in
                Task { await viewModel.loadData() }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .photosAll:
                    PhotosAllView()
                case .photoDetail(let photo):
                    PhotoDetailView(photo: photo)
                case .blogAll:
                    BlogAllView()
                case .blogDetail(let postId):
                    BlogPostDetailView(postId: postId)
                case .settings:
                    SettingsView()
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView {
                    await viewModel.loadData()
                }
            }
            .sheet(isPresented: $showBlogEditor) {
                BlogEditorView {
                    await viewModel.loadData()
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(model: notifications)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image("ArgoLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 36)

            Spacer()

            Text("Argonauta")
                .font(ArgoTheme.font(size: 20, weight: .bold))
                .foregroundStyle(ArgoTheme.interactiveAccent)

            Spacer()

            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(ArgoTheme.font(size: 20))
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                    if notifications.unreadCount > 0 {
                        Text(notifications.unreadCount > 9 ? "9+" : "\(notifications.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .accessibilityLabel("Meldingen")

            NavigationLink(value: HomeRoute.settings) {
                Image(systemName: "gearshape.fill")
                    .font(ArgoTheme.font(size: 20))
                    .foregroundStyle(ArgoTheme.interactiveAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Mededelingen

    private var announcementsSection: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.announcements) { announcement in
                HStack(spacing: 12) {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                        .font(ArgoTheme.font(size: 16))
                    Text(announcement.text)
                        .font(.argoBody)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(ArgoTheme.announcementTint)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Photo Section Header

    private var photoSectionHeader: some View {
        ZStack {
            HStack {
                Text("Foto's")
                    .font(ArgoTheme.font(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(value: HomeRoute.photosAll) {
                    HStack(spacing: 4) {
                        Text("Meer")
                            .font(ArgoTheme.font(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(ArgoTheme.font(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ArgoTheme.blueNormal)

            Button { showCamera = true } label: {
                ZStack {
                    Circle()
                        .fill(ArgoTheme.blueNormal)
                        .frame(width: 52, height: 52)
                    Circle()
                        .fill(ArgoTheme.blueDark)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .font(ArgoTheme.font(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -8)
        }
    }

    // MARK: - Blog Section Header

    private var blogSectionHeader: some View {
        ZStack {
            HStack {
                Text("Blog")
                    .font(ArgoTheme.font(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(value: HomeRoute.blogAll) {
                    HStack(spacing: 4) {
                        Text("Meer")
                            .font(ArgoTheme.font(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(ArgoTheme.font(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ArgoTheme.blueNormal)

            Button { showBlogEditor = true } label: {
                ZStack {
                    Circle()
                        .fill(ArgoTheme.blueNormal)
                        .frame(width: 52, height: 52)
                    Circle()
                        .fill(ArgoTheme.blueDark)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(ArgoTheme.font(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -8)
        }
    }

    // MARK: - Foto's

    private var photosSection: some View {
        VStack(spacing: 0) {
            photoSectionHeader

            if viewModel.recentPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(ArgoTheme.font(size: 32))
                        .foregroundStyle(ArgoTheme.iconAccent)
                    Text("Maak de eerste foto!")
                        .font(.argoSubheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(ArgoTheme.secondaryGroupedSurface)
            } else {
                let gridItems = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

                LazyVGrid(columns: gridItems, spacing: 2) {
                    let displayPhotos = Array(viewModel.recentPhotos.prefix(9))
                    ForEach(displayPhotos) { photo in
                        NavigationLink(value: HomeRoute.photoDetail(photo)) {
                            photoThumbnail(photo)
                        }
                    }
                }
            }
        }
    }

    private func photoThumbnail(_ photo: DashboardViewModel.Photo) -> some View {
        AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(ArgoTheme.tertiaryFill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(ArgoTheme.iconAccent)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }

    // MARK: - Blog

    private var blogSection: some View {
        VStack(spacing: 0) {
            blogSectionHeader

            VStack(spacing: 12) {
                ForEach(viewModel.recentPosts) { post in
                    NavigationLink(value: HomeRoute.blogDetail(post.id)) {
                        BlogCard(title: post.title, imageUrl: post.imageUrl,
                                 authorName: post.authorName, publishedAt: post.publishedAt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}
