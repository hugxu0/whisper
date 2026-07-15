import Foundation
import SwiftUI
import UIKit
import WhisperApp
import WhisperDomain

@main
@MainActor
struct WhisperApplication: App {
    private let dependencies: WhisperAppDependencies
    private let device: WhisperDeviceDescription

    init() {
        dependencies = .live(baseURL: AppConfiguration.baseURL)
        device = AppConfiguration.deviceDescription
    }

    var body: some Scene {
        WindowGroup {
            WhisperRootView(
                sessionController: dependencies.sessionController,
                device: device
            )
        }
    }
}

@MainActor
private enum AppConfiguration {
    private static let installationIDKey = "whisper.installation-id"

    static var baseURL: URL {
        guard let rawValue = Bundle.main.object(
            forInfoDictionaryKey: "WhisperAPIBaseURL"
        ) as? String,
        let url = URL(string: rawValue)
        else {
            preconditionFailure("WhisperAPIBaseURL is missing or invalid")
        }
        return url
    }

    static var deviceDescription: WhisperDeviceDescription {
        WhisperDeviceDescription(
            installationId: installationID,
            platform: UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios",
            deviceName: UIDevice.current.name,
            appVersion: bundleValue("CFBundleShortVersionString"),
            buildNumber: bundleValue("CFBundleVersion"),
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }

    private static var installationID: String {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: installationIDKey), value.count >= 8 {
            return value
        }

        let value = "ios_\(UUID().uuidString.lowercased())"
        defaults.set(value, forKey: installationIDKey)
        return value
    }

    private static func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
