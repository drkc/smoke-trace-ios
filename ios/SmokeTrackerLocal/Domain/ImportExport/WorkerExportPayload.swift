import Foundation

struct WorkerExportPayload: Decodable {
    let exportedAt: Date?
    let timezone: String?
    let logs: [WorkerExportLog]

    enum CodingKeys: String, CodingKey {
        case exportedAt = "exported_at"
        case timezone
        case logs
    }

    init(exportedAt: Date?, timezone: String?, logs: [WorkerExportLog]) {
        self.exportedAt = exportedAt
        self.timezone = timezone
        self.logs = logs
    }
}

struct WorkerExportLog: Decodable {
    let id: String
    let createdAt: Date
    let triggerPrimary: String
    let triggerSecondary: String?
    let delayed10min: Int?
    let minutesSinceLast: Int?
    let countInDay: Int?
    let isBackfill: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case triggerPrimary = "trigger_primary"
        case triggerSecondary = "trigger_secondary"
        case delayed10min = "delayed_10min"
        case minutesSinceLast = "minutes_since_last"
        case countInDay = "count_in_day"
        case isBackfill = "is_backfill"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        triggerPrimary = try container.decode(String.self, forKey: .triggerPrimary)
        triggerSecondary = container.decodeLossyStringIfPresent(forKey: .triggerSecondary)
        delayed10min = container.decodeLossyIntIfPresent(forKey: .delayed10min)
        minutesSinceLast = container.decodeLossyIntIfPresent(forKey: .minutesSinceLast)
        countInDay = container.decodeLossyIntIfPresent(forKey: .countInDay)
        isBackfill = container.decodeLossyIntIfPresent(forKey: .isBackfill)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        guard contains(key) else { return nil }

        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }

        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue ? 1 : 0
        }

        if let stringValue = try? decode(String.self, forKey: key) {
            let raw = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            if let intValue = Int(raw) { return intValue }
            if raw.caseInsensitiveCompare("true") == .orderedSame { return 1 }
            if raw.caseInsensitiveCompare("false") == .orderedSame { return 0 }
        }

        return nil
    }

    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        guard contains(key) else { return nil }

        if let stringValue = try? decode(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }

        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue ? "true" : "false"
        }

        return nil
    }
}
