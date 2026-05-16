import Foundation

struct BottleApplicationService {

    private static let wineBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    )
    private static let cxmenuBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxmenu"
    )
    private static let cxbottleBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxbottle"
    )

    static func addToBottle(
        executablePath: URL,
        bottleName: String,
        bottlePath: URL,
        onOutput: @Sendable @escaping (String) -> Void
    ) async throws {
        let fm = FileManager.default
        let driveC = bottlePath.appendingPathComponent("drive_c")
        let exePath = executablePath.path
        let exeFilename = executablePath.lastPathComponent

        let winePath: String

        if exePath.hasPrefix(driveC.path) {
            winePath = exePath.replacingOccurrences(of: driveC.path, with: "C:\\")
                .replacingOccurrences(of: "/", with: "\\")
        } else {
            let exeDir = executablePath.deletingLastPathComponent()
            let targetDir = driveC
                .appendingPathComponent("Program Files")
                .appendingPathComponent("Futureport82")
            let targetExe = targetDir.appendingPathComponent(exeFilename)

            if !fm.fileExists(atPath: targetDir.path) {
                onOutput("Copying game directory to bottle...\n")
                do {
                    try fm.copyItem(at: exeDir, to: targetDir)
                    onOutput("Copied directory structure to bottle.\n")
                } catch {
                    try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
                    try fm.copyItem(at: executablePath, to: targetExe)
                    onOutput("Warning: Could not copy full directory, copied exe only: \(error.localizedDescription)\n")
                }
            } else if !fm.fileExists(atPath: targetExe.path) {
                try fm.copyItem(at: executablePath, to: targetExe)
                onOutput("Copied \(exeFilename) to bottle.\n")
            }

            winePath = targetExe.path
                .replacingOccurrences(of: driveC.path, with: "C:\\")
                .replacingOccurrences(of: "/", with: "\\")
        }

        let wineDir = (winePath as NSString).deletingLastPathComponent
        let batchContent = "@echo off\ncd /d \"\(wineDir)\"\nstart \"\" \"\(winePath)\"\n"
        // Create Start Menu launcher for manual fallback.
        let startMenuPath = driveC.appendingPathComponent(
            "users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
        )
        try fm.createDirectory(at: startMenuPath, withIntermediateDirectories: true)
        let startMenuBatchFile = startMenuPath.appendingPathComponent("Futureport82.bat")
        do {
            try batchContent.write(to: startMenuBatchFile, atomically: true, encoding: .utf8)
            onOutput("Created Start Menu launcher in bottle.\n")
        } catch {
            onOutput("Warning: Could not create Start Menu launcher: \(error.localizedDescription)\n")
        }

        await createNativeWindowsShortcuts(
            bottlePath: bottlePath,
            bottleName: bottleName,
            winePath: winePath,
            onOutput: onOutput
        )
        await resyncBottleMenus(
            bottleName: bottleName,
            bottlePath: bottlePath,
            onOutput: onOutput
        )

        onOutput("Application available at: \(winePath)\n")

        // Shut down wineserver to release locks before CrossOver rebuilds launchers.
        await MediaFoundationService.shutdownWineserver(
            bottleName: bottleName,
            bottlePath: bottlePath,
            onOutput: onOutput
        )

        await rebuildCrossOverPrograms(onOutput: onOutput)
    }

    private static func createNativeWindowsShortcuts(
        bottlePath: URL,
        bottleName: String,
        winePath: String,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        let vbsFile = bottlePath.appendingPathComponent("drive_c/users/crossover/create_fp82_shortcuts.vbs")
        let winePathEsc = winePath.replacingOccurrences(of: "\\", with: "\\\\")
        let vbs = """
        Set oWS = WScript.CreateObject("WScript.Shell")
        Set oLink = oWS.CreateShortcut("C:\\users\\crossover\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Futureport82.lnk")
        oLink.TargetPath = "\(winePathEsc)"
        oLink.WorkingDirectory = "C:\\Program Files\\Futureport82"
        oLink.Description = "Futureport82"
        oLink.Save
        """
        do {
            try vbs.write(to: vbsFile, atomically: true, encoding: .utf8)
            let exitCode = try await ShellService.run(
                executable: wineBin,
                arguments: [
                    "--bottle", bottleName,
                    "--cx-app", "cscript.exe",
                    "//nologo", "C:\\users\\crossover\\create_fp82_shortcuts.vbs"
                ],
                onOutput: onOutput
            )
            if exitCode == 0 {
                onOutput("Created native Start Menu shortcut (.lnk).\n")
            } else {
                onOutput("Warning: shortcut creation returned exit code \(exitCode).\n")
            }
        } catch {
            onOutput("Warning: failed to create Windows shortcuts: \(error.localizedDescription)\n")
        }
        try? FileManager.default.removeItem(at: vbsFile)
    }

    private static func resyncBottleMenus(
        bottleName: String,
        bottlePath: URL,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        _ = try? await ShellService.run(
            executable: cxmenuBin,
            arguments: ["--bottle", bottleName, "--sync", "--mode", "install"],
            onOutput: onOutput
        )
        _ = try? await ShellService.run(
            executable: cxmenuBin,
            arguments: ["--bottle", bottleName, "--install"],
            onOutput: onOutput
        )
        _ = try? await ShellService.run(
            executable: cxbottleBin,
            arguments: ["--bottle", bottleName, "--install"],
            onOutput: onOutput
        )
        onOutput("Resynced CrossOver menus from native shortcuts.\n")
    }

    private static func rebuildCrossOverPrograms(
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        let script = """
        on waitForElement(procRef, checkScript, timeoutSeconds)
            set deadline to (current date) + timeoutSeconds
            repeat while (current date) is less than deadline
                tell application "System Events"
                    tell procRef
                        if (run script checkScript) then
                            return true
                        end if
                    end tell
                end tell
                delay 0.2
            end repeat
            return false
        end waitForElement

        tell application "CrossOver" to activate

        tell application "System Events"
            tell process "CrossOver"
                set rebuildReady to my waitForElement(it, "exists menu item \\\"Clear and Rebuild Programs…\\\" of menu 1 of menu bar item \\\"Configure\\\" of menu bar 1", 10)
                if not rebuildReady then error "CrossOver rebuild menu was not available."

                click menu item "Clear and Rebuild Programs…" of menu 1 of menu bar item "Configure" of menu bar 1

                set confirmReady to my waitForElement(it, "exists button \\\"Rebuild\\\" of window 1", 10)
                if not confirmReady then error "CrossOver rebuild confirmation did not appear."

                click button "Rebuild" of window 1
            end tell
        end tell
        """

        do {
            onOutput("Requesting CrossOver to clear and rebuild its program launchers...\n")
            _ = try await ShellService.run(
                executable: URL(fileURLWithPath: "/usr/bin/open"),
                arguments: ["-a", "CrossOver"],
                onOutput: { _ in }
            )
            _ = try await ShellService.run(
                executable: URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: ["-e", script],
                onOutput: onOutput
            )
            onOutput("CrossOver program launcher rebuild requested.\n")
        } catch {
            onOutput("Warning: Could not trigger CrossOver launcher rebuild automatically: \(error.localizedDescription)\n")
            onOutput("If the app does not appear immediately in CrossOver, use Configure -> Clear and Rebuild Programs…\n")
        }
    }
}
