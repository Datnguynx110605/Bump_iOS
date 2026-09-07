import SwiftUI

/// Icon + count pairing used for like/comment counters, sized via `@ScaledMetric` so it
/// grows with Dynamic Type. Non-interactive; `BumpToggleIconButton` is the tappable one.
struct ReactionCountLabel: View {
    let systemImage: String
    let count: Int
    var isActive = false
    var activeColor: Color = BumpColor.like
    var accessibilityLabel: String?
    @ScaledMetric private var iconSize: CGFloat

    init(
        systemImage: String,
        count: Int,
        isActive: Bool = false,
        activeColor: Color = BumpColor.like,
        size: CGFloat = BumpIconSize.medium,
        accessibilityLabel: String? = nil
    ) {
        self.systemImage = systemImage
        self.count = count
        self.isActive = isActive
        self.activeColor = activeColor
        self.accessibilityLabel = accessibilityLabel
        _iconSize = ScaledMetric(wrappedValue: size)
    }

    var body: some View {
        HStack(spacing: BumpSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(isActive ? activeColor : BumpColor.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityValue(Text("\(count)"))
    }
}

/// Shared on/off icon control behind every like and save button in the app.
///
/// Centralising it is what gets each of those four-plus call sites a 44pt tap target, a
/// pressed state, an accessible name, and the `.isSelected` trait — all of which the
/// hand-rolled `Button { } label: { Image }.buttonStyle(.plain)` version was missing.
struct BumpToggleIconButton: View {
    let isOn: Bool
    let onImage: String
    let offImage: String
    let label: String
    var activeColor: Color = Color.accentColor
    var size: CGFloat = BumpIconSize.medium
    let action: () -> Void

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? onImage : offImage)
                .font(.system(size: size * scale))
                .foregroundStyle(isOn ? activeColor : BumpColor.textSecondary)
                .symbolEffect(.bounce, value: isOn)
        }
        .buttonStyle(.bumpIcon)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
