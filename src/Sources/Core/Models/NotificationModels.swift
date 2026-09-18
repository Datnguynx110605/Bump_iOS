import Foundation

// Raw values are positional to match the server's `NotificationType` enum, which
// serializes as an integer (no JsonStringEnumConverter is registered on either
// the REST or SignalR pipeline) — keep the two enums in the same declared order.
enum NotificationType: Int, Decodable {
    case follow
    case postReaction
    case commentReaction
    case comment
}

struct NotificationSummaryDto: Decodable, Identifiable {
    let id: UUID
    let toAccountId: UUID
    let title: String
    let content: String
    let isSent: Bool
    let createdAt: Date
    let type: NotificationType?
    let targetId: UUID?
    let actorAccountId: UUID?
    let actorAvatar: AvatarDto?

    init(id: UUID, toAccountId: UUID, title: String, content: String, isSent: Bool, createdAt: Date, type: NotificationType?, targetId: UUID?, actorAccountId: UUID?, actorAvatar: AvatarDto?) {
        self.id = id
        self.toAccountId = toAccountId
        self.title = title
        self.content = content
        self.isSent = isSent
        self.createdAt = createdAt
        self.type = type
        self.targetId = targetId
        self.actorAccountId = actorAccountId
        self.actorAvatar = actorAvatar
    }

    private enum CodingKeys: String, CodingKey {
        case id, toAccountId, title, content, isSent, createdAt, type, targetId, actorAccountId, actorAvatar
    }

    // `type`/`targetId`/`actorAccountId`/`actorAvatar` are decoded leniently: if the server
    // ever changes how they're represented on the wire, a tap-to-navigate or avatar feature
    // silently degrading is preferable to the whole notifications list failing to load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        toAccountId = try container.decode(UUID.self, forKey: .toAccountId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        isSent = try container.decode(Bool.self, forKey: .isSent)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        type = try? container.decodeIfPresent(NotificationType.self, forKey: .type)
        targetId = try? container.decodeIfPresent(UUID.self, forKey: .targetId)
        actorAccountId = try? container.decodeIfPresent(UUID.self, forKey: .actorAccountId)
        actorAvatar = try? container.decodeIfPresent(AvatarDto.self, forKey: .actorAvatar)
    }

    var route: AppRoute? {
        guard let type, let targetId else { return nil }
        return type.route(for: targetId)
    }
}

extension NotificationType {
    func route(for targetId: UUID) -> AppRoute {
        switch self {
        case .follow: return .account(targetId)
        case .postReaction, .commentReaction, .comment: return .post(targetId)
        }
    }
}

// Resolves the custom keys on an APNs payload to a destination. The server describes the
// event with the same `type` and `targetId` the REST DTO carries, and the mapping from
// those to a screen stays here, in `NotificationType.route(for:)`, rather than being
// baked into the push by the server.
extension AppRoute {
    init?(pushPayload userInfo: [AnyHashable: Any]) {
        guard let rawType = userInfo["type"] as? Int,
              let type = NotificationType(rawValue: rawType),
              let idString = userInfo["targetId"] as? String,
              let id = UUID(uuidString: idString) else { return nil }

        self = type.route(for: id)
    }
}
