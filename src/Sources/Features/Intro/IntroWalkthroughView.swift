import SwiftUI

private struct IntroPage {
    let icon: String
    let title: String
    let message: String
}

/// First-launch walkthrough shown once per device, before login/sign-up. Anyone in a hurry
/// can tap Skip; everyone else pages through with Next until the final "Get started" CTA.
struct IntroWalkthroughView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [IntroPage] = [
        IntroPage(icon: "fork.knife", title: String(localized: "Find places worth the trip"), message: String(localized: "Real photos and honest ratings from people who actually went.")),
        IntroPage(icon: "camera", title: String(localized: "Share what you find"), message: String(localized: "Snap it, rate it, post it. Thirty seconds, start to finish.")),
        IntroPage(icon: "bubble.left.and.bubble.right", title: String(localized: "Help someone decide"), message: String(localized: "A like or a comment is often all it takes to point a friend somewhere good."))
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
                        .fill(index == pageIndex ? BumpColor.brand : BumpColor.fill)
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
                Text(pageIndex < pages.count - 1 ? "Next" : "Get started")
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
    /// Deliberately oversized. With no disc behind it the glyph has to carry the top
    /// third of the screen on its own, and a light stroke at this scale reads as an
    /// illustration rather than as a toolbar icon that wandered into the wrong place.
    @ScaledMetric private var iconSize: CGFloat = 86

    var body: some View {
        VStack(spacing: BumpSpacing.l) {
            Spacer(minLength: BumpSpacing.l)
            Image(systemName: page.icon)
                .font(.system(size: iconSize, weight: .ultraLight))
                .foregroundStyle(BumpColor.brand)
                .accessibilityHidden(true)
            VStack(spacing: BumpSpacing.s) {
                Text(page.title)
                    .font(BumpFont.title)
                    .foregroundStyle(BumpColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(BumpFont.body)
                    .foregroundStyle(BumpColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BumpSpacing.xl)
            }
            Spacer(minLength: BumpSpacing.xl)
        }
    }
}
