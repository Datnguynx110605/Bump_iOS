import SwiftUI

/// Keeps a screen's content current without the user pulling down.
///
/// A screen loads once in its own `.task` and, before this existed, never looked again:
/// the view model's `isEmpty` guard means revisiting a tab shows whatever was fetched the
/// first time, and pull-to-refresh was the only way forward. This modifier is the missing
/// half — it runs `action` when the screen comes back into view or the app returns to the
/// foreground after `interval` has passed, and every `interval` for as long as the screen
/// stays visible and the app is active.
///
/// Nothing runs while the screen is off-screen or the app is in the background: the loop
/// lives in a `.task(id:)` keyed on both, so it is torn down and restarted rather than
/// ticking against a screen nobody is looking at.
///
/// `action` is expected to be a freshness *probe*, not a reload. Reloading a list on a
/// timer moves content under a reading user; probing first means the list only changes
/// when there is genuinely something new to show, which is the one time movement is
/// welcome.
private struct AutoRefresh: ViewModifier {
    let interval: Duration
    let action: () async -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var lastRun: ContinuousClock.Instant?

    func body(content: Content) -> some View {
        content
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .task(id: "\(isVisible)-\(scenePhase == .active)") {
                guard isVisible, scenePhase == .active else { return }
                await runIfStale()
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { return }
                    await run()
                }
            }
    }

    /// Skips the very first appearance: the screen's own `.task` is doing the initial
    /// load right now, and running here too would double every cold open.
    private func runIfStale() async {
        guard let lastRun else {
            self.lastRun = .now
            return
        }
        guard lastRun.duration(to: .now) >= interval else { return }
        await run()
    }

    private func run() async {
        await action()
        lastRun = .now
    }
}

extension View {
    func autoRefresh(every interval: Duration, action: @escaping () async -> Void) -> some View {
        modifier(AutoRefresh(interval: interval, action: action))
    }
}
