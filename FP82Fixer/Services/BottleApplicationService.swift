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

        // Skip .lnk creation via cscript.exe for stability.
        // CrossOver can beachball on bottles after forced cscript termination.
        onOutput("Skipping Windows .lnk shortcut creation for stability.\n")

        onOutput("Application available at: \(winePath)\n")
        onOutput("Note: You may need to restart CrossOver or refresh the bottle to see it in the application menu.\n")

        // Shut down wineserver to release locks before CrossOver opens the bottle
        await MediaFoundationService.shutdownWineserver(
            bottleName: bottleName,
            bottlePath: bottlePath,
            onOutput: onOutput
        )
    }

    
}
