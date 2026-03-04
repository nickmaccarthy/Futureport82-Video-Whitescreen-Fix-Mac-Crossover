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

        // Create Start Menu launcher and ask CrossOver to resync menus.
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

        await resyncBottleMenus(bottleName: bottleName, onOutput: onOutput)

        onOutput("Application available at: \(winePath)\n")
        onOutput("Note: You may need to restart CrossOver or refresh the bottle to see it in the application menu.\n")

        // Shut down wineserver to release locks before CrossOver opens the bottle
        await MediaFoundationService.shutdownWineserver(
            bottleName: bottleName,
            bottlePath: bottlePath,
            onOutput: onOutput
        )
    }

    private static func resyncBottleMenus(
        bottleName: String,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        let syncExitCode = try? await ShellService.run(
            executable: cxmenuBin,
            arguments: ["--bottle", bottleName, "--sync", "--mode", "install"],
            onOutput: onOutput
        )
        if syncExitCode == 0 {
            onOutput("Resynced CrossOver menu entries for bottle.\n")
        } else {
            onOutput("Warning: Could not resync CrossOver menu entries automatically.\n")
        }

        _ = try? await ShellService.run(
            executable: cxbottleBin,
            arguments: ["--bottle", bottleName, "--install"],
            onOutput: onOutput
        )
    }
}
