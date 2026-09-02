import SwiftUI

/// Icon + count pairing used for like/comment counters on posts and comments,
/// sized via `@ScaledMetric` so it grows with Dynamic Type.
struct ReactionCountLabel: View {
    let systemImage: String
    let count: Int
    var isActive = false
    var activeColor: Color = BumpColor.like
    @ScaledMetric private var iconSize: CGFloat

    init(systemImage: String, count: Int, isActive: Bool = false, activeColor: Color = BumpColor.like, size: CGFloat = BumpIconSize.medium) {
        self.systemImage = systemImage
        self.count = count
        self.isActive = isActive
        self.activeColor = activeColor
        _iconSize = ScaledMetric(wrappedValue: size)
    }

    var body: some View {
        HStack(spacing: BumpSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(isActive ? activeColor : BumpColor.textSecondary)
        .accessibilityElement(children: .combine)
    }
}
