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
            BumpBrandPalette.gradient
                .ignoresSafeArea()

            BumpLogoShape()
                .fill(Color.white, style: FillStyle(eoFill: true))
                .frame(width: 160, height: 160)
                .offset(y: dropOffset)
                .scaleEffect(scale)
                .opacity(logoOpacity)
        }
        .opacity(isFadingOut ? 0 : 1)
        .onAppear {
            // Reduce Motion still gets the mark, just without the settle. The dwell time
            // is unchanged so the launch doesn't feel different in length, only in travel.
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : BumpMotion.bouncy) {
                dropOffset = 0
                scale = 1
                logoOpacity = 1
            }
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.35)) {
                    isFadingOut = true
                }
                try? await Task.sleep(for: .milliseconds(350))
                onFinished()
            }
        }
    }
}
