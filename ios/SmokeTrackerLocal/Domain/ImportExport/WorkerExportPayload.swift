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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exportedAt = container.decodeLossyDateIfPresent(forKey: .exportedAt)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        logs = try container.decode([WorkerExportLog].self, forKey: .logs)
    }
}

struct WorkerExportLog: Decodable {
    let id: String
    let createdAt: Date?
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
        createdAt = container.decodeLossyDateIfPresent(forKey: .createdAt)
        triggerPrimary = try container.decode(String.self, forKey: .triggerPrimary)
        triggerSecondary = container.decodeLossyStringIfPresent(forKey: .triggerSecondary)
        delayed10min = container.decodeLossyIntIfPresent(forKey: .delayed10min)
        minutesSinceLast = container.decodeLossyIntIfPresent(forKey: .minutesSinceLast)
        countInDay = container.decodeLossyIntIfPresent(forKey: .countInDay)
        isBackfill = container.decodeLossyIntIfPresent(forKey: .isBackfill)
    }
}

private enum DateParsers {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let fallbackFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        return formats.map { format in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = format
            return df
        }
    }()

    static func parseDateString(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let d = iso8601Fractional.date(from: value) { return d }
        if let d = iso8601.date(from: value) { return d }
        for formatter in fallbackFormatters {
            if let d = formatter.date(from: value) { return d }
        }

        if let timestamp = Double(value) {
            return parseUnixTimestamp(timestamp)
        }

        return nil
    }

    static func parseUnixTimestamp(_ raw: Double) -> Date {
        // Heuristic: millisecond timestamps are usually > 1e12
        if raw > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: raw / 1000)
        }
        return Date(timeIntervalSince1970: raw)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDate(forKey key: Key) throws -> Date {
        if let stringValue = try? decode(String.self, forKey: key),
           let parsed = DateParsers.parseDateString(stringValue) {
            return parsed
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return DateParsers.parseUnixTimestamp(Double(intValue))
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return DateParsers.parseUnixTimestamp(doubleValue)
        }

        if let dateValue = try? decode(Date.self, forKey: key) {
            return dateValue
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected date in ISO8601 / yyyy-MM-dd HH:mm:ss / unix timestamp"
        )
    }

    func decodeLossyDateIfPresent(forKey key: Key) -> Date? {
        guard contains(key) else { return nil }
        return try? decodeLossyDate(forKey: key)
    }

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
