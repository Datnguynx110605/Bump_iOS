import SwiftUI

/// Read-only star rating. Announced as a single value ("4 out of 5 stars") instead of
/// five separate images, and filled/outline shapes carry the rating so it doesn't rest
/// on color alone.
///
/// Unearned stars stay on `textSecondary`. A lighter hairline tone looks calmer beside the
/// shop name, but the empty stars are what say *out of five* — they carry the scale, so
/// they are a meaningful non-text element and owe 3:1 against the surface. `hairline`
/// measures about 1.3:1 on a light page, which is a decorative rule, not a gauge.
struct RatingStarsView: View {
    /// Deliberately off the 4pt grid. Five stars have to read as one rating, and at
    /// `BumpSpacing.xs` they separate into five individual glyphs; this is optical
    /// spacing inside a single component, not layout spacing between components.
    fileprivate static let clusterGap: CGFloat = 2

    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = BumpIconSize.xs
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: Self.clusterGap) {
            ForEach(0..<maxRating, id: \.self) { index in
                BumpIcon(.star, index < rating ? .filled : .outline, size: size * scale)
                    .foregroundStyle(index < rating ? BumpColor.rating : BumpColor.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rating"))
        .accessibilityValue(String(localized: "\(rating) out of \(maxRating) stars"))
    }
}

/// Interactive counterpart used when composing a post. Each star is a real `Button` with
/// a full-size tap target — an `onTapGesture` on a bare `Image` gives no button
/// semantics, no pressed feedback, and a target smaller than 44pt.
///
/// Picking a rating is one of the two things a post is *for*, so it gets a real moment:
/// the chosen star springs, the ones below it fill in, and a haptic confirms the pick.
struct RatingPickerView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    @ScaledMetric private var starSize: CGFloat = BumpIconSize.large

    var body: some View {
        HStack(spacing: BumpSpacing.xs) {
            ForEach(1...maxRating, id: \.self) { value in
                Button {
                    rating = value
                    HapticFeedback.selected()
                } label: {
                    BumpIcon(.star, value <= rating ? .filled : .outline, size: starSize)
                        .foregroundStyle(value <= rating ? BumpColor.rating : BumpColor.textSecondary)
                        .scaleEffect(value == rating ? 1.12 : 1)
                        .bumpAnimation(BumpMotion.bouncy, value: rating)
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
