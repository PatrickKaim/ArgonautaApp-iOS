import SwiftUI

struct ArgoLogo: View {
    var size: CGFloat = 80

    var body: some View {
        Image("ArgoLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
