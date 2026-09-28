import Foundation
import SignalRClient

private struct NotificationPushDto: Decodable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: String
    let type: NotificationType?
    let targetId: UUID?
    let actorAccountId: UUID?
    let actorAvatar: ActorAvatarPushDto?
}

// Only the URL is needed for display. `AvatarDto.createdAt` is a `Date`, and unlike
// `APICoding.decoder` (used for REST), the SignalR hub protocol's decoder has no
// custom date strategy — so a nested `AvatarDto` would fail to decode .NET's date format here.
private struct ActorAvatarPushDto: Decodable {
    let url: String
}

/// Keeps the in-app notification list live. It draws no banners: iOS drops this socket
/// seconds after the app backgrounds, so every banner comes from APNs instead — see
/// `PushRegistration`.
@MainActor
final class NotificationHubClient: NSObject, HubConnectionDelegate {
    var onNotification: ((NotificationSummaryDto) -> Void)?

    private let baseURL: URL
    private let authSession: AuthSession
    private var connection: HubConnection?

    init(baseURL: URL, authSession: AuthSession) {
        self.baseURL = baseURL
        self.authSession = authSession
        super.init()
    }

    func start() {
        guard connection == nil else { return }

        let hubConnection = HubConnectionBuilder(url: baseURL.appendingPathComponent("hubs/notification"))
            .withHttpConnectionOptions { [weak authSession] options in
                options.accessTokenProvider = { authSession?.accessToken }
            }
            .withAutoReconnect()
            .withHubConnectionDelegate(delegate: self)
            .build()

        hubConnection.on(method: "ReceiveNotification") { [weak self] (payload: NotificationPushDto) in
            Task { @MainActor [weak self] in
                guard let self, let accountId = self.authSession.accountId else { return }
                self.onNotification?(NotificationSummaryDto(
                    id: payload.id,
                    toAccountId: accountId,
                    title: payload.title,
                    content: payload.content,
                    isSent: true,
                    createdAt: DotNetDate.parse(payload.createdAt) ?? Date(),
                    type: payload.type,
                    targetId: payload.targetId,
                    actorAccountId: payload.actorAccountId,
                    actorAvatar: payload.actorAvatar.map { AvatarDto(url: $0.url, createdAt: Date()) }
                ))
            }
        }

        connection = hubConnection
        hubConnection.start()
    }

    func stop() {
        connection?.stop()
        connection = nil
    }

    nonisolated func connectionDidOpen(hubConnection: HubConnection) {}

    nonisolated func connectionDidFailToOpen(error: Error) {
        #if DEBUG
        print("NotificationHubClient failed to connect: \(error)")
        #endif
    }

    nonisolated func connectionDidClose(error: Error?) {}
}
