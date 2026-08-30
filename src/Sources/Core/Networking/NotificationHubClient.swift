import Foundation
import SignalRClient

private struct NotificationPushDto: Decodable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: String
}

@MainActor
final class NotificationHubClient: NSObject, HubConnectionDelegate {
    var onNotification: ((NotificationSummaryDto) -> Void)?

    private let baseURL: URL
    private let authSession: AuthSession
    private var connection: HubConnection?

    init(baseURL: URL, authSession: AuthSession) {
        self.baseURL = baseURL
        self.authSession = authSession
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
                    createdAt: DotNetDate.parse(payload.createdAt) ?? Date()
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
