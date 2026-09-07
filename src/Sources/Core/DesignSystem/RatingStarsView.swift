import SwiftUI

/// Read-only star rating. Announced as a single value ("4 out of 5 stars") instead of
/// five separate images, and filled/outline shapes carry the rating so it doesn't rest
/// on color alone.
struct RatingStarsView: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = BumpIconSize.xs
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: size * scale))
                    .foregroundStyle(index < rating ? BumpColor.rating : BumpColor.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rating"))
        .accessibilityValue(String(localized: "\(rating) out of \(maxRating) stars"))
    }
}

/// Interactive counterpart used when composing a post. Each star is a real `Button` with
/// a full-size tap target — the previous `onTapGesture` on a bare `Image` gave no button
/// semantics, no pressed feedback, and a target smaller than 44pt.
struct RatingPickerView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    @ScaledMetric private var starSize: CGFloat = BumpIconSize.large

    var body: some View {
        HStack(spacing: BumpSpacing.xs) {
            ForEach(1...maxRating, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: starSize))
                        .foregroundStyle(value <= rating ? BumpColor.rating : BumpColor.textSecondary)
                }
                .buttonStyle(.bumpIcon)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rating"))
        .accessibilityValue(String(localized: "\(rating) out of \(maxRating) stars"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, maxRating)
            case .decrement: rating = max(rating - 1, 1)
            default: break
            }
        }
    }
}
