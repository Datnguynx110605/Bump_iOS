import SwiftUI

struct BumpPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                configuration.label
            }
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: BumpRadius.control))
        .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(BumpMotion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BumpPrimaryButtonStyle {
    static var bumpPrimary: BumpPrimaryButtonStyle { BumpPrimaryButtonStyle() }
    static func bumpPrimary(isLoading: Bool) -> BumpPrimaryButtonStyle { BumpPrimaryButtonStyle(isLoading: isLoading) }
}

struct BumpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: BumpRadius.control))
    }
}

extension TextFieldStyle where Self == BumpTextFieldStyle {
    static var bump: BumpTextFieldStyle { BumpTextFieldStyle() }
}
