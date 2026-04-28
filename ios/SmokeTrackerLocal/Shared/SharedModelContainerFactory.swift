import Foundation
import SwiftData

enum SharedModelContainerFactory {
    static let appGroupIdentifier = "group.LRS7YLA5GN.eY3UkMP"

    private static let migrationMarkerKey = "storage.migrated.to_app_group.v1"
    private static let defaultStoreFilename = "default.store"

    private static var schema: Schema {
        Schema([
            SmokeLog.self,
            AppSetting.self,
            CravingEvent.self,
        ])
    }

    static let shared: ModelContainer = {
        migrateLegacyStoreIfNeeded()
        do {
            return try makeContainer()
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }()

    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupIdentifier)
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func migrateLegacyStoreIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: migrationMarkerKey) {
            return
        }

        defer {
            defaults.set(true, forKey: migrationMarkerKey)
        }

        let fileManager = FileManager.default

        guard let groupRoot = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }

        let groupAppSupport = groupRoot
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        guard let oldAppSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let sourceBase = oldAppSupport.appendingPathComponent(defaultStoreFilename)
        let destinationBase = groupAppSupport.appendingPathComponent(defaultStoreFilename)

        if fileManager.fileExists(atPath: destinationBase.path) {
            return
        }

        if !fileManager.fileExists(atPath: sourceBase.path) {
            return
        }

        do {
            try fileManager.createDirectory(at: groupAppSupport, withIntermediateDirectories: true)
            try copyStoreFamily(baseSource: sourceBase, baseDestination: destinationBase)
        } catch {
            return
        }
    }

    private static func copyStoreFamily(baseSource: URL, baseDestination: URL) throws {
        let fileManager = FileManager.default
        let suffixes = ["", "-wal", "-shm"]

        for suffix in suffixes {
            let source = URL(fileURLWithPath: baseSource.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = URL(fileURLWithPath: baseDestination.path + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }
}
