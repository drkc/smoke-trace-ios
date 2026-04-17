import Foundation
import SwiftData

@Model
final class SmokeLog {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var triggerPrimaryRaw: String
    var triggerSecondary: String?
    var delayed10min: Bool
    var minutesSinceLast: Int?
    var countInDay: Int

    var insightTypeRaw: String?
    var insightPrimaryTriggerRaw: String?
    var insightAction: String?
    var insightError: String?
    var isBackfill: Bool

    init(
        id: String = UUID().uuidString,
        createdAt: Date,
        triggerPrimary: TriggerPrimary,
        triggerSecondary: String? = nil,
        delayed10min: Bool = false,
        minutesSinceLast: Int? = nil,
        countInDay: Int = 1,
        insightType: InsightType? = nil,
        insightPrimaryTrigger: TriggerPrimary? = nil,
        insightAction: String? = nil,
        insightError: String? = nil,
        isBackfill: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.triggerPrimaryRaw = triggerPrimary.rawValue
        self.triggerSecondary = triggerSecondary
        self.delayed10min = delayed10min
        self.minutesSinceLast = minutesSinceLast
        self.countInDay = countInDay
        self.insightTypeRaw = insightType?.rawValue
        self.insightPrimaryTriggerRaw = insightPrimaryTrigger?.rawValue
        self.insightAction = insightAction
        self.insightError = insightError
        self.isBackfill = isBackfill
    }

    var triggerPrimary: TriggerPrimary {
        get { TriggerPrimary(rawValue: triggerPrimaryRaw) ?? .other }
        set { triggerPrimaryRaw = newValue.rawValue }
    }

    var insightType: InsightType? {
        get { insightTypeRaw.flatMap(InsightType.init(rawValue:)) }
        set { insightTypeRaw = newValue?.rawValue }
    }

    var insightPrimaryTrigger: TriggerPrimary? {
        get { insightPrimaryTriggerRaw.flatMap(TriggerPrimary.init(rawValue:)) }
        set { insightPrimaryTriggerRaw = newValue?.rawValue }
    }
}
