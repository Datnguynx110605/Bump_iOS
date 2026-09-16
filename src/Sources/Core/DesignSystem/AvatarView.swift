import SwiftUI

/// Circular profile image.
///
/// Always decorative: every place it appears, the account's name is already on screen as
/// text, so it stays out of the accessibility tree rather than making VoiceOver announce
/// each row twice.
///
/// The ring is a hairline in the divider colour, not a brand tint. On a page with no
/// elevation the avatar is already the darkest, busiest object in its row; a coloured ring
/// around it competes with the name beside it for the eye.
struct AvatarView: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                CachedAsyncImage(url: imageURL, targetSize: CGSize(width: size, height: size)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(BumpColor.hairline, lineWidth: BumpStroke.hairline))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Circle()
            .fill(BumpColor.surfaceTertiary)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(BumpColor.brandMuted)
            }
    }
}
