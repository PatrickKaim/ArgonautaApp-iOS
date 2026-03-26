import SwiftUI
import UIKit

enum BlogBlockType: String, CaseIterable, Identifiable {
    case title
    case paragraph
    case heading
    case image
    case separator

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Titel"
        case .paragraph: "Tekst"
        case .heading: "Heading"
        case .image: "Foto"
        case .separator: "Scheidingslijn"
        }
    }

    var icon: String {
        switch self {
        case .title: "textformat.size"
        case .paragraph: "text.alignleft"
        case .heading: "textformat"
        case .image: "camera.fill"
        case .separator: "minus"
        }
    }
}

struct EditableBlock: Identifiable {
    let id: String
    var type: BlogBlockType
    var textContent: String
    var headingLevel: Int
    var imageURL: String?
    var imageCaption: String
    var localImage: UIImage?

    init(type: BlogBlockType, textContent: String = "", headingLevel: Int = 2) {
        self.id = UUID().uuidString
        self.type = type
        self.textContent = textContent
        self.headingLevel = headingLevel
        self.imageURL = nil
        self.imageCaption = ""
        self.localImage = nil
    }

    func toServerDict() -> [String: Any] {
        switch type {
        case .title:
            return ["type": "title", "content": textContent]
        case .paragraph:
            return ["type": "paragraph", "content": textContent]
        case .heading:
            return ["type": "heading", "content": ["level": headingLevel, "text": textContent] as [String: Any]]
        case .image:
            return ["type": "image", "content": ["url": imageURL ?? "", "caption": imageCaption] as [String: Any]]
        case .separator:
            return ["type": "separator", "content": [:] as [String: Any]]
        }
    }

    static func fromServerDict(_ dict: [String: Any]) -> EditableBlock? {
        guard let type = dict["type"] as? String else { return nil }
        var block: EditableBlock
        switch type {
        case "title":
            block = EditableBlock(type: .title, textContent: dict["content"] as? String ?? "")
        case "paragraph":
            block = EditableBlock(type: .paragraph, textContent: dict["content"] as? String ?? "")
        case "heading":
            if let content = dict["content"] as? [String: Any] {
                let level = content["level"] as? Int ?? 2
                let text = content["text"] as? String ?? ""
                block = EditableBlock(type: .heading, textContent: text, headingLevel: level)
            } else {
                block = EditableBlock(type: .heading)
            }
        case "image":
            block = EditableBlock(type: .image)
            if let content = dict["content"] as? [String: Any] {
                block.imageURL = URLResolver.resolve(content["url"] as? String)
                block.imageCaption = content["caption"] as? String ?? ""
            }
        case "separator":
            block = EditableBlock(type: .separator)
        default:
            return nil
        }
        return block
    }
}

enum BlogVisibility: String {
    case publicAccess = "public"
    case membersOnly = "members_only"
}

@Observable
final class BlogEditorViewModel {
    var headerTitle = ""
    var blocks: [EditableBlock] = []
    var isSaving = false
    var isPublishing = false
    var isUploadingImage = false
    var isUploadingHeaderImage = false
    var errorMessage: String?
    var blogId: String?

    var headerImage: UIImage?
    var headerImageMediaId: String?
    var headerImageUrl: String?
    var blogStatus: String?

    var isPublished: Bool { blogStatus == "published" }
    var isPendingReview: Bool { blogStatus == "pending_review" }

    var canPublishDirectly: Bool {
        AppState.shared.canManageCMS
    }

    private let meteor = MeteorService.shared

    func loadBlog(id: String) async {
        do {
            guard let result = try await meteor.call("blogs.get", params: [id]) as? [String: Any] else { return }
            blogId = id
            headerTitle = result["headerTitle"] as? String ?? ""
            headerImageMediaId = result["headerImageMediaId"] as? String
            blogStatus = result["status"] as? String
            let rawUrl = result["headerImageLandscape"] as? String
                ?? result["headerImageSquare"] as? String
                ?? result["headerImageUrl"] as? String
            headerImageUrl = URLResolver.resolve(rawUrl)
            if let serverBlocks = result["blocks"] as? [[String: Any]] {
                blocks = serverBlocks.compactMap { EditableBlock.fromServerDict($0) }
            }
        } catch {
            errorMessage = "Laden mislukt: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func save() async -> String? {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            await uploadPendingImages()
            await uploadPendingHeaderImage()

            let blockDicts = blocks.map { $0.toServerDict() }
            var doc: [String: Any] = ["headerTitle": headerTitle, "blocks": blockDicts]
            if let mediaId = headerImageMediaId {
                doc["headerImageMediaId"] = mediaId
            }

            if let existingId = blogId {
                _ = try await meteor.call("blogs.update", params: [existingId, doc])
                return existingId
            } else {
                doc["visibility"] = "public"
                let result = try await meteor.call("blogs.insert", params: [doc])
                if let newId = result as? String {
                    blogId = newId
                    return newId
                }
                return nil
            }
        } catch {
            errorMessage = "Opslaan mislukt: \(error.localizedDescription)"
            return nil
        }
    }

    func publish(visibility: BlogVisibility) async -> Bool {
        isPublishing = true
        errorMessage = nil
        defer { isPublishing = false }

        do {
            await uploadPendingImages()
            await uploadPendingHeaderImage()

            let blockDicts = blocks.map { $0.toServerDict() }
            var doc: [String: Any] = ["headerTitle": headerTitle, "blocks": blockDicts, "visibility": visibility.rawValue]
            if let mediaId = headerImageMediaId {
                doc["headerImageMediaId"] = mediaId
            }

            if let existingId = blogId {
                _ = try await meteor.call("blogs.update", params: [existingId, doc])
            } else {
                let result = try await meteor.call("blogs.insert", params: [doc])
                if let newId = result as? String {
                    blogId = newId
                }
            }

            guard let id = blogId else {
                errorMessage = "Blog kon niet worden opgeslagen"
                return false
            }

            let submitResult = try await meteor.call("blogs.submitForReview", params: [id])
            if let dict = submitResult as? [String: Any], dict["published"] as? Bool == true {
                return true
            }
            return true
        } catch {
            errorMessage = "Publiceren mislukt: \(error.localizedDescription)"
            return false
        }
    }

    func updatePublished() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let existingId = blogId else {
            errorMessage = "Geen blog om bij te werken"
            return false
        }

        do {
            await uploadPendingImages()
            await uploadPendingHeaderImage()

            let blockDicts = blocks.map { $0.toServerDict() }
            var doc: [String: Any] = ["headerTitle": headerTitle, "blocks": blockDicts]
            if let mediaId = headerImageMediaId {
                doc["headerImageMediaId"] = mediaId
            }

            _ = try await meteor.call("blogs.update", params: [existingId, doc])
            return true
        } catch {
            errorMessage = "Bijwerken mislukt: \(error.localizedDescription)"
            return false
        }
    }

    func uploadHeaderImage(_ image: UIImage) async {
        isUploadingHeaderImage = true
        defer { isUploadingHeaderImage = false }

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
        let base64 = jpegData.base64EncodedString()
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        let crops = Self.computeHeaderCrops(width: w, height: h)

        do {
            let result = try await meteor.call("media.uploadHeader", params: [base64, crops])
            if let dict = result as? [String: Any],
               let mediaId = dict["mediaId"] as? String,
               let variants = dict["variants"] as? [String: String] {
                headerImageMediaId = mediaId
                headerImageUrl = URLResolver.resolve(variants["landscape"] ?? variants["square"])
                headerImage = image
            }
        } catch {
            errorMessage = "Header afbeelding upload mislukt: \(error.localizedDescription)"
        }
    }

    /// Bereken center-crops voor portrait (2:3), square (1:1) en landscape (16:9) vanuit de bron-afmetingen
    static func computeHeaderCrops(width w: Int, height h: Int) -> [String: Any] {
        func centerCrop(targetAspect: Double) -> [String: Any] {
            let sourceAspect = Double(w) / Double(h)
            let cropW: Int, cropH: Int
            if sourceAspect > targetAspect {
                cropH = h
                cropW = Int(Double(h) * targetAspect)
            } else {
                cropW = w
                cropH = Int(Double(w) / targetAspect)
            }
            let x = (w - cropW) / 2
            let y = (h - cropH) / 2
            return ["x": x, "y": y, "width": cropW, "height": cropH]
        }
        return [
            "portrait": centerCrop(targetAspect: 2.0 / 3.0),
            "square": centerCrop(targetAspect: 1.0),
            "landscape": centerCrop(targetAspect: 16.0 / 9.0)
        ]
    }

    func uploadImage(image: UIImage) async -> (url: String, mediaId: String)? {
        isUploadingImage = true
        defer { isUploadingImage = false }

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }
        let base64 = jpegData.base64EncodedString()
        let crop: [String: Any] = [
            "x": 0, "y": 0,
            "width": Int(image.size.width),
            "height": Int(image.size.height)
        ]

        do {
            let result = try await meteor.call("media.uploadBlock", params: [base64, crop])
            if let dict = result as? [String: Any],
               let url = dict["url"] as? String,
               let mediaId = dict["mediaId"] as? String {
                return (url, mediaId)
            }
        } catch {
            errorMessage = "Foto upload mislukt: \(error.localizedDescription)"
        }
        return nil
    }

    func addBlock(_ type: BlogBlockType, at index: Int? = nil) {
        let block = EditableBlock(type: type)
        if let index, index < blocks.count {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
    }

    func removeBlock(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks.remove(at: index)
    }

    func moveBlock(from source: IndexSet, to destination: Int) {
        blocks.move(fromOffsets: source, toOffset: destination)
    }

    private func uploadPendingHeaderImage() async {
        if let image = headerImage, headerImageMediaId == nil {
            await uploadHeaderImage(image)
        }
    }

    private func uploadPendingImages() async {
        for i in blocks.indices {
            if blocks[i].type == .image, let localImage = blocks[i].localImage, blocks[i].imageURL == nil {
                if let result = await uploadImage(image: localImage) {
                    blocks[i].imageURL = result.url
                    blocks[i].localImage = nil
                }
            }
        }
    }
}
