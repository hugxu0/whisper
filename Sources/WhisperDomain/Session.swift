import Foundation

public struct WhisperAccount: Codable, Equatable, Sendable {
    public let username: String
    public let name: String
    public let avatar: String?

    public init(username: String, name: String, avatar: String? = nil) {
        self.username = username
        self.name = name
        self.avatar = avatar
    }
}

public struct WhisperDeviceDescription: Codable, Equatable, Sendable {
    public let installationId: String
    public let platform: String
    public let deviceName: String
    public let appVersion: String
    public let buildNumber: String
    public let locale: String
    public let timezone: String

    public init(
        installationId: String,
        platform: String = "ios",
        deviceName: String,
        appVersion: String,
        buildNumber: String,
        locale: String,
        timezone: String
    ) {
        self.installationId = installationId
        self.platform = platform
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.locale = locale
        self.timezone = timezone
    }
}

public struct WhisperLoginRequest: Codable, Equatable, Sendable {
    public let username: String
    public let password: String
    public let device: WhisperDeviceDescription

    public init(username: String, password: String, device: WhisperDeviceDescription) {
        self.username = username
        self.password = password
        self.device = device
    }
}

public struct WhisperLoginResponse: Codable, Equatable, Sendable {
    public let token: String
    public let username: String
    public let name: String
    public let deviceId: String

    public init(token: String, username: String, name: String, deviceId: String) {
        self.token = token
        self.username = username
        self.name = name
        self.deviceId = deviceId
    }
}

public struct WhisperReadStates: Codable, Equatable, Sendable {
    public let couple: [String: Int64]
    public let ai: [String: Int64]
}

public struct WhisperSharedStateEntry: Codable, Equatable, Sendable {
    public let value: WhisperJSONValue
    public let updatedBy: String
    public let updatedAt: Int64
}

public struct WhisperSharedUpdate: Codable, Equatable, Sendable {
    public let key: String
    public let value: WhisperJSONValue
    public let updatedBy: String
    public let updatedAt: Int64
}

public struct WhisperBootstrapResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let serverTime: Int64
    public let accounts: [WhisperAccount]
    public let messages: [WhisperChannel: [WhisperMessage]]
    public let readStates: WhisperReadStates
    public let sharedState: [String: WhisperSharedStateEntry]

    private enum CodingKeys: String, CodingKey {
        case ok
        case serverTime
        case accounts
        case messages
        case readStates
        case sharedState
    }

    public init(
        ok: Bool,
        serverTime: Int64,
        accounts: [WhisperAccount],
        messages: [WhisperChannel: [WhisperMessage]],
        readStates: WhisperReadStates,
        sharedState: [String: WhisperSharedStateEntry]
    ) {
        self.ok = ok
        self.serverTime = serverTime
        self.accounts = accounts
        self.messages = messages
        self.readStates = readStates
        self.sharedState = sharedState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMessages = try container.decode([String: [WhisperMessage]].self, forKey: .messages)
        let messages = Dictionary(uniqueKeysWithValues: rawMessages.compactMap { key, value in
            guard let channel = WhisperChannel(rawValue: key) else { return nil }
            return (channel, value)
        })

        self.init(
            ok: try container.decode(Bool.self, forKey: .ok),
            serverTime: try container.decode(Int64.self, forKey: .serverTime),
            accounts: try container.decode([WhisperAccount].self, forKey: .accounts),
            messages: messages,
            readStates: try container.decode(WhisperReadStates.self, forKey: .readStates),
            sharedState: try container.decode([String: WhisperSharedStateEntry].self, forKey: .sharedState)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawMessages = Dictionary(uniqueKeysWithValues: messages.map { ($0.key.rawValue, $0.value) })
        try container.encode(ok, forKey: .ok)
        try container.encode(serverTime, forKey: .serverTime)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(rawMessages, forKey: .messages)
        try container.encode(readStates, forKey: .readStates)
        try container.encode(sharedState, forKey: .sharedState)
    }
}
