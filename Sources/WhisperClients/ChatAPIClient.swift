import Foundation
import WhisperDomain

public struct WhisperMessagePageRequest: Equatable, Sendable {
    public let channel: WhisperChannel
    public let since: Int64?
    public let after: Int64?
    public let before: Int64?
    public let around: Int64?
    public let limit: Int

    public init(
        channel: WhisperChannel,
        since: Int64? = nil,
        after: Int64? = nil,
        before: Int64? = nil,
        around: Int64? = nil,
        limit: Int = 80
    ) {
        self.channel = channel
        self.since = since
        self.after = after
        self.before = before
        self.around = around
        self.limit = min(max(limit, 1), 300)
    }
}

public struct WhisperMediaUpload: Equatable, Sendable {
    public let data: Data
    public let filename: String
    public let mimeType: String
    public let purpose: WhisperUploadPurpose

    public init(
        data: Data,
        filename: String,
        mimeType: String,
        purpose: WhisperUploadPurpose = .message
    ) {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
        self.purpose = purpose
    }
}

public protocol WhisperChatAPI: Sendable {
    func messages(_ request: WhisperMessagePageRequest) async throws -> WhisperMessagePage
    func sync(cursor: Int64, limit: Int) async throws -> WhisperSyncPage
    func acknowledgeSync(cursor: Int64) async throws
    func upload(_ upload: WhisperMediaUpload) async throws -> WhisperUploadResult
}

private struct WhisperOKResponse: Decodable {
    let ok: Bool
}

extension WhisperAPIClient: WhisperChatAPI {
    public func messages(_ request: WhisperMessagePageRequest) async throws -> WhisperMessagePage {
        guard token != nil else { throw WhisperAPIError.missingToken }
        return try await send(
            endpoint: .messages(
                channel: request.channel,
                since: request.since,
                after: request.after,
                before: request.before,
                around: request.around,
                limit: request.limit
            ),
            method: .get,
            requiresToken: true
        )
    }

    public func sync(cursor: Int64, limit: Int) async throws -> WhisperSyncPage {
        guard token != nil else { throw WhisperAPIError.missingToken }
        return try await send(
            endpoint: .sync(cursor: cursor, limit: min(max(limit, 1), 500)),
            method: .get,
            requiresToken: true
        )
    }

    public func acknowledgeSync(cursor: Int64) async throws {
        guard token != nil else { throw WhisperAPIError.missingToken }
        let body = try JSONEncoder().encode(["cursor": cursor])
        let response: WhisperOKResponse = try await send(
            endpoint: .syncAck,
            method: .post,
            body: body,
            requiresToken: true
        )
        guard response.ok else { throw WhisperAPIError.decoding }
    }

    public func upload(_ upload: WhisperMediaUpload) async throws -> WhisperUploadResult {
        guard token != nil else { throw WhisperAPIError.missingToken }
        guard upload.data.count <= 50 * 1_024 * 1_024 else {
            throw WhisperAPIError.uploadTooLarge
        }

        let boundary = "WhisperBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let body = Self.multipartBody(upload: upload, boundary: boundary)
        return try await send(
            endpoint: .upload(purpose: upload.purpose),
            method: .post,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            requiresToken: true
        )
    }

    private static func multipartBody(upload: WhisperMediaUpload, boundary: String) -> Data {
        let safeFilename = upload.filename
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        var result = Data()
        result.append(Data("--\(boundary)\r\n".utf8))
        result.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\n".utf8))
        result.append(Data("Content-Type: \(upload.mimeType)\r\n\r\n".utf8))
        result.append(upload.data)
        result.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return result
    }
}
