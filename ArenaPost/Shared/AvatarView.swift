import ArenaKit
import SwiftUI

struct AvatarView: View {
    let user: User?
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: user?.avatar) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Text(user?.initials ?? "")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
