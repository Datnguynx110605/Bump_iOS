import SwiftUI

struct WelcomeView: View {
    @Binding var path: [OnboardingRoute]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BumpSpacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 96, height: 96)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(.largeTitle, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Bump")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text("Discover great local spots through the people around you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BumpSpacing.xl)
            }

            Spacer()

            VStack(spacing: BumpSpacing.m) {
                Button("Get Started") {
                    path.append(.signUpEmail)
                }
                .buttonStyle(.bumpPrimary)

                Button {
                    path.append(.login)
                } label: {
                    Text("I already have an account")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.top, BumpSpacing.xs)
            }
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BumpColor.surface)
    }
}
