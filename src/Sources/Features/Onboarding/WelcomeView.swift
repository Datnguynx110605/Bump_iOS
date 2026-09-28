import SwiftUI

struct WelcomeView: View {
    @Binding var path: [OnboardingRoute]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BumpSpacing.m) {
                // The same mark the app icon and splash use, so the first screen a new
                // user sees matches the icon they just tapped.
                BumpLogoMark(size: 104)

                Text("Bump")
                    .font(BumpFont.display)
                    .foregroundStyle(BumpColor.textPrimary)

                Text("The best places, found the way they always were — through people who've been.")
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BumpSpacing.xl)
            }

            Spacer()

            VStack(spacing: BumpSpacing.m) {
                Button("Get started") {
                    path.append(.signUpEmail)
                }
                .buttonStyle(.bumpPrimary)

                Button("I already have an account") {
                    path.append(.login)
                }
                .buttonStyle(.bumpText)
            }
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BumpColor.surface)
    }
}
