#if os(iOS)
import AVFoundation
import Foundation
import Observation

struct WhisperRecordedVoice: Sendable {
    let data: Data
    let filename: String
    let mimeType: String
    let duration: TimeInterval
}

enum WhisperVoiceRecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "没有麦克风权限，请在系统设置中允许 Whisper 使用麦克风。"
        case .couldNotStart: return "无法开始录音，请稍后重试。"
        }
    }
}

@MainActor
@Observable
final class WhisperVoiceRecorder {
    private(set) var isRecording = false
    private(set) var startedAt: Date?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var recordingURL: URL?

    func toggle() async throws -> WhisperRecordedVoice? {
        if isRecording { return try stop() }
        try await start()
        return nil
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        startedAt = nil
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil
    }

    private func start() async throws {
        let allowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard allowed else { throw WhisperVoiceRecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-voice-\(UUID().uuidString.lowercased()).m4a")
        let recorder = try AVAudioRecorder(
            url: url,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )
        recorder.prepareToRecord()
        guard recorder.record() else { throw WhisperVoiceRecorderError.couldNotStart }
        self.recorder = recorder
        self.recordingURL = url
        self.startedAt = Date()
        self.isRecording = true
    }

    private func stop() throws -> WhisperRecordedVoice {
        guard let recorder, let recordingURL else {
            throw WhisperVoiceRecorderError.couldNotStart
        }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil
        self.startedAt = nil
        self.isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let data = try Data(contentsOf: recordingURL)
        try? FileManager.default.removeItem(at: recordingURL)
        return WhisperRecordedVoice(
            data: data,
            filename: "voice-\(Int(Date().timeIntervalSince1970)).m4a",
            mimeType: "audio/m4a",
            duration: duration
        )
    }
}
#endif
