import Foundation

struct BottleApplicationService {

    private static let wineBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
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

        // Create batch file shortcut on desktop
        let desktopPath = driveC
            .appendingPathComponent("users/crossover/Desktop")
        try fm.createDirectory(at: desktopPath, withIntermediateDirectories: true)

        let wineDir = (winePath as NSString).deletingLastPathComponent
        let batchContent = "@echo off\ncd /d \"\(wineDir)\"\nstart \"\" \"\(winePath)\"\n"
        let batchFile = desktopPath.appendingPathComponent("Futureport82.bat")

        do {
            try batchContent.write(to: batchFile, atomically: true, encoding: .utf8)
            onOutput("Created batch file shortcut on desktop.\n")
        } catch {
            onOutput("Warning: Could not create batch file: \(error.localizedDescription)\n")
        }

        // Try creating a Windows shortcut via VBScript (best-effort, 3s timeout)
        await createWindowsShortcut(
            winePath: winePath,
            shortcutDir: desktopPath,
            shortcutName: "Futureport82.lnk",
            bottleName: bottleName,
            driveC: driveC,
            onOutput: onOutput
        )

        // Create Start Menu shortcut
        let startMenuPath = driveC.appendingPathComponent(
            "users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
        )
        try fm.createDirectory(at: startMenuPath, withIntermediateDirectories: true)

        await createWindowsShortcut(
            winePath: winePath,
            shortcutDir: startMenuPath,
            shortcutName: "Futureport82.lnk",
            bottleName: bottleName,
            driveC: driveC,
            onOutput: onOutput
        )

        onOutput("Application available at: \(winePath)\n")
        onOutput("Note: You may need to restart CrossOver or refresh the bottle to see it in the application menu.\n")

        // Shut down wineserver to release locks before CrossOver opens the bottle
        await MediaFoundationService.shutdownWineserver(
            bottleName: bottleName,
            bottlePath: bottlePath,
            onOutput: onOutput
        )
    }

    private static func createWindowsShortcut(
        winePath: String,
        shortcutDir: URL,
        shortcutName: String,
        bottleName: String,
        driveC: URL,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        let shortcutPath = shortcutDir.appendingPathComponent(shortcutName)
        let vbsFile = shortcutDir.appendingPathComponent("create_shortcut.vbs")
        let wineDir = (winePath as NSString).deletingLastPathComponent

        let winePathEsc = winePath.replacingOccurrences(of: "\\", with: "\\\\")
        let shortcutPathEsc = shortcutPath.path.replacingOccurrences(of: "\\", with: "\\\\")
        let wineDirEsc = wineDir.replacingOccurrences(of: "\\", with: "\\\\")

        let vbsContent = """
        Set oWS = WScript.CreateObject("WScript.Shell")
        sLinkFile = "\(shortcutPathEsc)"
        Set oLink = oWS.CreateShortcut(sLinkFile)
        oLink.TargetPath = "\(winePathEsc)"
        oLink.WorkingDirectory = "\(wineDirEsc)"
        oLink.Description = "Futureport82"
        oLink.Save
        """

        do {
            try vbsContent.write(to: vbsFile, atomically: true, encoding: .utf8)

            let vbsWinePath = vbsFile.path
                .replacingOccurrences(of: driveC.path, with: "C:\\")
                .replacingOccurrences(of: "/", with: "\\")

            let process = Process()
            process.executableURL = wineBin
            process.arguments = [
                "--bottle", bottleName,
                "--cx-app", "cscript.exe", "//nologo", vbsWinePath
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            try process.run()

            let completed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                DispatchQueue.global().async {
                    var elapsed: TimeInterval = 0
                    while process.isRunning && elapsed < 3.0 {
                        Thread.sleep(forTimeInterval: 0.1)
                        elapsed += 0.1
                    }
                    if process.isRunning {
                        // Use SIGKILL (like Python's process.kill()) not SIGTERM
                        kill(process.processIdentifier, SIGKILL)
                        process.waitUntilExit()
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: process.terminationStatus == 0)
                    }
                }
            }

            if completed {
                onOutput("Created Windows shortcut.\n")
            } else {
                onOutput("Skipped Windows shortcut creation (timed out).\n")
            }
        } catch {
            // Non-critical
        }

        try? FileManager.default.removeItem(at: vbsFile)
    }
}
