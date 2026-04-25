import AppKit
import AVFoundation
import ApplicationServices
import Foundation

public struct Permissions {
    static func ensureMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Microphone: granted")
        case .notDetermined:
            print("Microphone: requesting...")
            let semaphore = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("Microphone: \(granted ? "granted" : "denied")")
                semaphore.signal()
            }
            semaphore.wait()
        default:
            print("Microphone: denied — grant in System Settings → Privacy & Security → Microphone")
        }
    }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Check if Input Monitoring permission is granted.
    /// Uses CGPreflightListenEventAccess (public CoreGraphics API, macOS 10.15+).
    public static func isInputMonitoringGranted() -> Bool {
        return CGPreflightListenEventAccess()
    }

    /// Request Input Monitoring permission by triggering the system prompt.
    /// Returns true if already granted, false if the user needs to grant it.
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        return CGRequestListenEventAccess()
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    static func didUpgrade() -> Bool {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/open-wispr")
        let versionFile = configDir.appendingPathComponent(".last-version")
        let current = OpenWispr.version
        let previous = try? String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if previous == current {
            return false
        }

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? current.write(to: versionFile, atomically: true, encoding: .utf8)
        return true
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
