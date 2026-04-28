import Foundation
import SwiftData

@Model
final class AppSetting {
    @Attribute(.unique) var id: Int
    var pinEnabled: Bool
    var pinHash: String?
    var biometricsEnabled: Bool
    var timezoneIdentifier: String
    var suggestionEngineEnabled: Bool
    var cessationPlanStartDate: Date?

    init(
        id: Int = 1,
        pinEnabled: Bool = false,
        pinHash: String? = nil,
        biometricsEnabled: Bool = false,
        timezoneIdentifier: String = TimeZone.current.identifier,
        suggestionEngineEnabled: Bool = true,
        cessationPlanStartDate: Date? = nil
    ) {
        self.id = id
        self.pinEnabled = pinEnabled
        self.pinHash = pinHash
        self.biometricsEnabled = biometricsEnabled
        self.timezoneIdentifier = timezoneIdentifier
        self.suggestionEngineEnabled = suggestionEngineEnabled
        self.cessationPlanStartDate = cessationPlanStartDate
    }
}

extension AppSetting {
    static func fetchOrCreate(in context: ModelContext) -> AppSetting {
        if let existing = try? context.fetch(FetchDescriptor<AppSetting>()).first(where: { $0.id == 1 }) {
            return existing
        }

        let setting = AppSetting(id: 1)
        context.insert(setting)
        try? context.save()
        return setting
    }
}
