import SwiftUI

/// Short, bouncy launch moment for the pin logo, shown once over `RootView` at cold
/// start before revealing the intro or the app itself.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var dropOffset: CGFloat = -260
    @State private var scale: CGFloat = 0.6
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
            // The bouncy drop is the first thing every cold launch shows — exactly the
            // kind of motion Reduce Motion exists to suppress. The mark still settles and
            // the dwell time is unchanged; it just doesn't travel to get there.
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .interpolatingSpring(stiffness: 170, damping: 12)) {
                dropOffset = 0
                scale = 1
                logoOpacity = 1
            }
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeOut(duration: 0.35)) {
                    isFadingOut = true
                }
                try? await Task.sleep(for: .milliseconds(350))
                onFinished()
            }
        }
    }
}
