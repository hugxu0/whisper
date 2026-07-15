import Foundation
import WhisperDomain

public protocol WhisperOutboxClient: Sendable {
    func load() async throws -> [WhisperOutboxItem]
    func save(_ item: WhisperOutboxItem) async throws
    func remove(clientID: String) async throws
}

public actor WhisperInMemoryOutboxClient: WhisperOutboxClient {
    private var items: [String: WhisperOutboxItem]

    public init(items: [WhisperOutboxItem] = []) {
        self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    public func load() -> [WhisperOutboxItem] {
        items.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ item: WhisperOutboxItem) {
        items[item.id] = item
    }

    public func remove(clientID: String) {
        items.removeValue(forKey: clientID)
    }
}

public actor WhisperFileOutboxClient: WhisperOutboxClient {
    private let fileURL: URL
    private var loaded = false
    private var items: [String: WhisperOutboxItem] = [:]

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func live(filename: String = "chat-outbox-v1.json") -> WhisperFileOutboxClient {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return WhisperFileOutboxClient(
            fileURL: baseURL.appendingPathComponent("Whisper", isDirectory: true)
                .appendingPathComponent(filename)
        )
    }

    public func load() throws -> [WhisperOutboxItem] {
        try ensureLoaded()
        return items.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ item: WhisperOutboxItem) throws {
        try ensureLoaded()
        items[item.id] = item
        try persist()
    }

    public func remove(clientID: String) throws {
        try ensureLoaded()
        items.removeValue(forKey: clientID)
        try persist()
    }

    private func ensureLoaded() throws {
        guard loaded == false else { return }
        loaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([WhisperOutboxItem].self, from: data)
        items = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(items.values.sorted { $0.createdAt < $1.createdAt })
        try data.write(to: fileURL, options: .atomic)
    }
}
