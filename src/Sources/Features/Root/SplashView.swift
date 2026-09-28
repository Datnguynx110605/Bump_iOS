import SwiftUI

/// The launch moment: the pin mark settling onto the brand tile, shown once over
/// `RootView` at cold start before revealing the intro or the app itself.
///
/// The mark scales up and fades in rather than dropping in from off-screen. A long travel
/// is the kind of motion that is charming the first time and tiring by the tenth launch —
/// and a launch screen is seen more often than any other screen in the app. This one is
/// over in under a second and never moves anything more than a few points.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var dropOffset: CGFloat = -18
    @State private var scale: CGFloat = 0.88
    @State private var logoOpacity: Double = 0
    @State private var isFadingOut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BumpBrandPalette.tile
                .ignoresSafeArea()

            BumpLogoShape.mark(inkWidth: 190)
                .offset(y: dropOffset)
                .scaleEffect(scale)
                .opacity(logoOpacity)
        }
        .opacity(isFadingOut ? 0 : 1)
        .onAppear {
            // Reduce Motion still gets the mark, just without the settle. The dwell time
            // is unchanged so the launch doesn't feel different in length, only in travel.
            withAnimation(reduceMotion ? BumpMotion.fade : BumpMotion.bouncy) {
                dropOffset = 0
                scale = 1
                logoOpacity = 1
            }
            Task {
                try? await Task.sleep(for: Self.dwell)
                // Guarded like the settle above it. This line used to animate
                // unconditionally on a hardcoded 0.35s while the line directly above it
                // respected the setting — the same function disagreeing with itself.
                withAnimation(reduceMotion ? nil : BumpMotion.fade) {
                    isFadingOut = true
                }
                // Derived from the fade, not a second magic number that happened to
                // match it. Handing control over before the splash has finished fading
                // shows the root view punching through a half-transparent tile.
                try? await Task.sleep(for: reduceMotion ? .zero : Self.fadeOut)
                onFinished()
            }
        }
    }

    /// How long the mark holds before handing over. Long enough to read as intentional,
    /// short enough that it never becomes the thing standing between you and the app.
    private static let dwell: Duration = .milliseconds(900)
    /// Matches `BumpMotion.fade`, which is what actually drives the fade.
    private static let fadeOut: Duration = .milliseconds(220)
}
