import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Detail van een kalender-event — zelfde bron als de website (`events.getPublic`).
struct CalendarEventDetailView: View {
    let slugOrId: String
    let occurrence: String?

    @State private var eventDoc: [String: Any]?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let meteor = MeteorService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    LoadingView(message: "Activiteit laden...")
                        .padding(.top, 40)
                } else if let err = errorMessage {
                    Text(err)
                        .font(.argoBody)
                        .foregroundStyle(.red)
                        .padding(.top, 24)
                } else if let doc = eventDoc {
                    detailContent(doc)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Activiteit")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func detailContent(_ doc: [String: Any]) -> some View {
        let title = displayTitle(from: doc)
        let teaser = displayTeaser(from: doc)
        let blocksText = plainTextFromBlocks(doc["blocks"])
        let imagePath = (doc["headerImageLandscape"] as? String) ?? (doc["headerImageUrl"] as? String)
        let imageUrl = URLResolver.resolve(imagePath)

        if let imageUrl {
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    Color.clear.frame(height: 0)
                @unknown default:
                    EmptyView()
                }
            }
        }

        Text(title)
            .font(.argoHeadline)
            .foregroundStyle(ArgoTheme.editorTitle)

        Text(formatRange(start: doc["start"], end: doc["end"], occurrence: doc["occurrenceDate"]))
            .font(.argoBody)
            .foregroundStyle(.secondary)

        if !teaser.isEmpty {
            Text(teaser)
                .font(.argoBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let desc = doc["description"] as? String, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  blocksText.isEmpty {
            Text(desc)
                .font(.argoBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !blocksText.isEmpty {
            Text(blocksText)
                .font(.argoBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let url = websiteURL(from: doc) {
            Button {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
            } label: {
                Label("Volledige pagina op de website", systemImage: "safari")
                    .font(ArgoTheme.font(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ArgoTheme.blueNormal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        eventDoc = nil
        do {
            let options: [String: Any]
            if let occ = occurrence {
                options = ["occurrence": occ]
            } else {
                options = [:]
            }
            guard let result = try await meteor.call("events.getPublic", params: [slugOrId, options]) as? [String: Any] else {
                errorMessage = "Kon activiteit niet laden."
                isLoading = false
                return
            }
            eventDoc = result
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    private func displayTitle(from doc: [String: Any]) -> String {
        if let h = doc["headerTitle"] as? String, !h.isEmpty { return h }
        if let t = doc["title"] as? String, !t.isEmpty { return t }
        return "Activiteit"
    }

    private func displayTeaser(from doc: [String: Any]) -> String {
        if let t = doc["teaser"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        return ""
    }

    private func formatRange(start: Any?, end: Any?, occurrence: Any?) -> String {
        guard let sDate = parseDate(start) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .full
        f.timeStyle = .short
        var s = f.string(from: sDate)
        if let eDate = parseDate(end) {
            let tf = DateFormatter()
            tf.locale = Locale(identifier: "nl_NL")
            tf.dateStyle = .none
            tf.timeStyle = .short
            s += " – " + tf.string(from: eDate)
        }
        if let od = parseDate(occurrence) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "nl_NL")
            df.dateStyle = .full
            df.timeStyle = .none
            s += " (" + df.string(from: od) + ")"
        }
        return s
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let t = value as? TimeInterval { return Date(timeIntervalSince1970: t) }
        if let dict = value as? [String: Any], let inner = dict["$date"] {
            return parseDate(inner)
        }
        return nil
    }

    /// Platte tekst uit blog-achtige blokken (paragraph, heading, …).
    private func plainTextFromBlocks(_ blocks: Any?) -> String {
        guard let arr = blocks as? [[String: Any]] else { return "" }
        var parts: [String] = []
        for block in arr {
            guard let type = block["type"] as? String else { continue }
            switch type {
            case "paragraph":
                if let c = block["content"] as? String, !c.isEmpty { parts.append(c) }
            case "title":
                if let c = block["content"] as? String, !c.isEmpty { parts.append(c) }
            case "heading":
                if let c = block["content"] as? [String: Any], let t = c["text"] as? String, !t.isEmpty {
                    parts.append(t)
                }
            case "quote":
                if let c = block["content"] as? [String: Any], let t = c["text"] as? String, !t.isEmpty {
                    parts.append(t)
                }
            case "list":
                if let c = block["content"] as? [String: Any], let items = c["items"] as? [String] {
                    parts.append(items.filter { !$0.isEmpty }.joined(separator: "\n"))
                }
            case "code":
                if let c = block["content"] as? [String: Any], let code = c["code"] as? String, !code.isEmpty {
                    parts.append(code)
                }
            case "button":
                if let c = block["content"] as? [String: Any], let t = c["text"] as? String, !t.isEmpty {
                    parts.append(t)
                }
            default:
                break
            }
        }
        return parts.joined(separator: "\n\n")
    }

    private func websiteURL(from doc: [String: Any]) -> URL? {
        let slug = (doc["detailSlug"] as? String) ?? (doc["_id"] as? String) ?? slugOrId
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let path = "\(URLResolver.baseURL)/events/\(encoded)"
        guard var comp = URLComponents(string: path) else { return nil }
        if let occ = occurrence {
            comp.queryItems = [URLQueryItem(name: "occurrence", value: occ)]
        }
        return comp.url
    }
}
