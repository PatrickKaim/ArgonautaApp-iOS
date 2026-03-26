import SwiftUI

struct ArgoCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: ArgoTheme.cardShadow, radius: 8, x: 0, y: 2)
    }
}
