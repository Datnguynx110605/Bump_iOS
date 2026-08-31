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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(BumpSpacing.m)
                }
            }
            .frame(height: 44)

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    IntroPageView(page: page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(BumpMotion.standard, value: pageIndex)

            HStack(spacing: BumpSpacing.s) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? BumpColor.brand : BumpColor.fill)
                        .frame(width: index == pageIndex ? 20 : 6, height: 6)
                        .animation(BumpMotion.quick, value: pageIndex)
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
    }
}

private struct IntroPageView: View {
    fileprivate let page: IntroPage

    var body: some View {
        VStack(spacing: BumpSpacing.l) {
            Spacer(minLength: BumpSpacing.l)
            Image(systemName: page.icon)
                .font(.system(size: 96))
                .foregroundStyle(BumpColor.brand)
                .accessibilityHidden(true)
            VStack(spacing: BumpSpacing.s) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BumpSpacing.xl)
            }
            Spacer(minLength: BumpSpacing.xl)
        }
    }
}
