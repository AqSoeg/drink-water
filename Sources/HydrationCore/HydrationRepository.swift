import Foundation

public struct HydrationRepository: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationDefault() throws -> HydrationRepository {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("DrinkWater", isDirectory: true)
        return HydrationRepository(fileURL: directory.appendingPathComponent("hydration.json"))
    }

    public func load() throws -> HydrationDocument {
        // Only a missing file means a fresh install. Unreadable or corrupt data must never be overwritten.
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return HydrationDocument() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(HydrationDocument.self, from: Data(contentsOf: fileURL))
        try document.validate()
        return document
    }

    public func save(_ document: HydrationDocument) throws {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
