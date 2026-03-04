import Foundation
import ApplicationServices

struct PermissionService {
    struct Status {
        let accessibilityTrusted: Bool
        let appleEventsTrusted: Bool

        var allGranted: Bool {
            accessibilityTrusted && appleEventsTrusted
        }
    }

    static func requestStartupPrompts() {
        _ = checkAccessibility(prompt: true)
        _ = checkAppleEvents(prompt: true)
    }

    static func checkRequiredPermissions(prompt: Bool) -> Status {
        Status(
            accessibilityTrusted: checkAccessibility(prompt: prompt),
            appleEventsTrusted: checkAppleEvents(prompt: prompt)
        )
    }

    private static func checkAccessibility(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private static func checkAppleEvents(prompt: Bool) -> Bool {
        // A lightweight System Events query triggers the Automation permission prompt.
        let script = "tell application \"System Events\" to count (every process)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        if !prompt {
            process.arguments = ["-s", "o", "-e", script]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
