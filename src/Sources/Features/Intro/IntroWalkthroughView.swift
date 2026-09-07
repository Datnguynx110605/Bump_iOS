import SwiftUI

private struct IntroPage {
    let icon: String
    let title: String
    let message: String
}

/// First-launch walkthrough shown once per device, before login/sign-up. Anyone in a hurry
/// can tap Skip; everyone else pages through with Next until the final "Get Started" CTA.
struct IntroWalkthroughView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [IntroPage] = [
        IntroPage(icon: "fork.knife.circle.fill", title: String(localized: "Discover great spots"), message: String(localized: "Browse real photos and ratings from people who've actually been there.")),
        IntroPage(icon: "camera.fill", title: String(localized: "Share what you find"), message: String(localized: "Snap a photo, rate the place, and bump it to your feed in seconds.")),
        IntroPage(icon: "bubble.left.and.bubble.right.fill", title: String(localized: "Talk about it"), message: String(localized: "React and comment on posts to help others decide where to go next."))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if pageIndex < pages.count - 1 {
                    Button("Skip", action: onFinish)
                        .buttonStyle(.bumpText)
                        .padding(.horizontal, BumpSpacing.m)
                }
            }
            .frame(height: BumpHitTarget.min)

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    IntroPageView(page: page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .bumpAnimation(BumpMotion.standard, value: pageIndex)

            HStack(spacing: BumpSpacing.s) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? Color.accentColor : BumpColor.fill)
                        .frame(width: index == pageIndex ? 20 : 6, height: 6)
                        .bumpAnimation(BumpMotion.quick, value: pageIndex)
                }
            }
            .padding(.bottom, BumpSpacing.l)

            Button {
                if pageIndex < pages.count - 1 {
                    pageIndex += 1
                } else {
                    onFinish()
                }
            } label: {
                Text(pageIndex < pages.count - 1 ? "Next" : "Get Started")
            }
            .buttonStyle(.bumpPrimary)
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        .background(BumpColor.surface)
        .accessibilityAction(named: Text("Skip")) { onFinish() }
    }
}

private struct IntroPageView: View {
    fileprivate let page: IntroPage
    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.hero
    @ScaledMetric private var discSize: CGFloat = 128

    var body: some View {
        VStack(spacing: BumpSpacing.l) {
            Spacer(minLength: BumpSpacing.l)
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: discSize, height: discSize)
                .overlay {
                    Image(systemName: page.icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)
            VStack(spacing: BumpSpacing.s) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(BumpColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(BumpColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BumpSpacing.xl)
            }
            Spacer(minLength: BumpSpacing.xl)
        }
    }
}
