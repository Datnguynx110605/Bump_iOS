import SwiftUI

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
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.accentColor)
            }
    }
}
