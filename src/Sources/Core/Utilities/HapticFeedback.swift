import UIKit

@MainActor
enum HapticFeedback {
    static func reacted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
