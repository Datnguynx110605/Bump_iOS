import SwiftUI

struct RatingStarsView: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index < rating ? .yellow : .secondary.opacity(0.4))
            }
        }
    }
}

struct RatingPickerView: View {
    @Binding var rating: Int
    var maxRating: Int = 5

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: 28))
                    .foregroundStyle(value <= rating ? .yellow : .secondary.opacity(0.4))
                    .onTapGesture { rating = value }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Rating"))
        .accessibilityValue(String(localized: "\(rating) out of \(maxRating) stars"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, maxRating)
            case .decrement: rating = max(rating - 1, 0)
            default: break
            }
        }
    }
}
