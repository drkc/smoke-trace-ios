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

    init(
        id: Int = 1,
        pinEnabled: Bool = false,
        pinHash: String? = nil,
        biometricsEnabled: Bool = false,
        timezoneIdentifier: String = TimeZone.current.identifier,
        suggestionEngineEnabled: Bool = true
    ) {
        self.id = id
        self.pinEnabled = pinEnabled
        self.pinHash = pinHash
        self.biometricsEnabled = biometricsEnabled
        self.timezoneIdentifier = timezoneIdentifier
        self.suggestionEngineEnabled = suggestionEngineEnabled
    }
}
