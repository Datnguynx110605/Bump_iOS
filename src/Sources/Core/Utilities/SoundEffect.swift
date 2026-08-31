import AudioToolbox

/// Built-in iOS system sound IDs (no bundled audio assets). Limited to an ID that's
/// reliably documented across iOS versions to avoid picking a number that plays nothing.
/// Incoming notifications get their sound from the native banner (`UNNotificationSound.default`)
/// instead, so it isn't duplicated here.
enum SoundEffect: SystemSoundID {
    /// A short, light "tink" — used for actions the user just took (reacting, posting, commenting).
    case confirm = 1057

    func play() {
        AudioServicesPlaySystemSound(rawValue)
    }
}
