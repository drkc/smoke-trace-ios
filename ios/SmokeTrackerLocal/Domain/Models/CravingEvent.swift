import Foundation
import SwiftData

enum CravingEventStatus: String, Codable {
    case pending
    case smoked
    case resisted
}

@Model
final class CravingEvent {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var triggerPrimaryRaw: String
    var triggerSecondary: String?
    var statusRaw: String
    var resolvedAt: Date?
    var linkedSmokeLogID: String?

    init(
        id: String = UUID().uuidString,
        createdAt: Date,
        triggerPrimary: TriggerPrimary,
        triggerSecondary: String? = nil,
        status: CravingEventStatus = .pending,
        resolvedAt: Date? = nil,
        linkedSmokeLogID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.triggerPrimaryRaw = triggerPrimary.rawValue
        self.triggerSecondary = triggerSecondary
        self.statusRaw = status.rawValue
        self.resolvedAt = resolvedAt
        self.linkedSmokeLogID = linkedSmokeLogID
    }

    var triggerPrimary: TriggerPrimary {
        get { TriggerPrimary(rawValue: triggerPrimaryRaw) ?? .other }
        set { triggerPrimaryRaw = newValue.rawValue }
    }

    var status: CravingEventStatus {
        get { CravingEventStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
