import SwiftUI

/// The shape every onboarding form screen has: content down the page, one primary action
/// pinned to the bottom.
///
/// All seven screens built this by hand as `VStack { content; Spacer(); button }`. A
/// `VStack` has nowhere to put overflow, so at the larger Dynamic Type sizes — or simply
/// with the keyboard raised on a small phone — the fields, the inline hints and the error
/// banner were clipped off the bottom of the screen with no way to reach them. Every other
/// surface in the app scales with `@ScaledMetric`; the sign-in flow was the exception, and
/// it is the one flow a new user cannot skip.
///
/// `Spacer()` can't come along: it collapses to nothing inside a `ScrollView`. Pinning the
/// action with `safeAreaInset` keeps it exactly where it was for short content while
/// letting tall content scroll underneath it.
struct AuthFormLayout<Content: View, Action: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var action: () -> Action

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BumpSpacing.l) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        // Keeps the short screens feeling fixed rather than rubber-banding over an inch
        // of empty space, while the tall ones still scroll.
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(BumpColor.surface)
        .safeAreaInset(edge: .bottom) {
            action()
                .padding(.horizontal, BumpSpacing.l)
                .padding(.top, BumpSpacing.s)
                .padding(.bottom, BumpSpacing.l)
                .background(BumpColor.surface)
        }
    }
}
