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
                .font(.custom("ArialMT", size: size * 0.4))
                .foregroundStyle(.arenaSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.arenaFill)
        }
        .frame(width: size, height: size)
        // Are.na avatars are square.
        .clipShape(Rectangle())
        .accessibilityHidden(true)
    }
}
