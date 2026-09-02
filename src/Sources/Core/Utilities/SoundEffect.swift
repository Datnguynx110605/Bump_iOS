import AudioToolbox

/// Built-in iOS system sound IDs (no bundled audio assets). Limited to an ID that's
/// reliably documented across iOS versions to avoid picking a number that plays nothing.
/// Incoming notifications get their sound from the native banner (`UNNotificationSound.default`)
/// instead, so it isn't duplicated here.
///
/// Reactions (likes) and follows are intentionally silent — haptics alone confirm those.
/// Sound is reserved for the two moments a user actively publishes something: posting
/// and commenting.
enum SoundEffect: SystemSoundID {
    /// Apple's built-in "tweet sent" chime — a short, soft confirmation tone with the
    /// same "you just posted" character as Facebook/Instagram's send sounds.
    /// NOTE: ID picked from documented system-sound references, not audited by ear
    /// in this environment (no simulator available) — worth a quick listen before shipping.
    case sent = 1016

    func play() {
        AudioServicesPlaySystemSound(rawValue)
    }
}
