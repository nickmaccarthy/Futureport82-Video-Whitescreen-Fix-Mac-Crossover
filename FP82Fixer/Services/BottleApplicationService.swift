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
    private static let cxstartBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
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

        await registerApplicationMenuEntry(
            bottlePath: bottlePath,
            winePath: winePath,
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

    private static func registerApplicationMenuEntry(
        bottlePath: URL,
        winePath: String,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        // Match CrossOver's native Start Menu/Desktop path style so the app
        // entry appears in bottle UI consistently.
        let startMenuPath = "StartMenu.C^3A_users_crossover_AppData_Roaming_Microsoft_Windows_Start+Menu/Programs/Futureport82.lnk"
        let desktopPath = "Desktop.C^3A_users_crossover_Desktop/Futureport82.lnk"
        let legacyStartMenuPath = "StartMenu/Futureport82"
        let legacyDesktopPath = "Desktop/Futureport82"

        let wrapperScripts = ensureMenuWrapperScripts(
            bottlePath: bottlePath,
            winePath: winePath
        )
        let commandByPath: [String: String] = [
            startMenuPath: "\"\(wrapperScripts.startMenu.path)\"",
            desktopPath: "\"\(wrapperScripts.desktop.path)\""
        ]
        let menuPaths = [startMenuPath, desktopPath]
        var createOK = true

        for legacyPath in [legacyStartMenuPath, legacyDesktopPath] {
            _ = try? await ShellService.run(
                executable: cxmenuBin,
                arguments: ["--bottle", bottlePath.path, "--filter", legacyPath, "--delete"],
                onOutput: onOutput
            )
        }

        for menuPath in menuPaths {
            // Best-effort cleanup in case a prior entry exists.
            _ = try? await ShellService.run(
                executable: cxmenuBin,
                arguments: ["--bottle", bottlePath.path, "--filter", menuPath, "--delete"],
                onOutput: onOutput
            )

            let exitCode = try? await ShellService.run(
                executable: cxmenuBin,
                arguments: [
                    "--bottle", bottlePath.path,
                    "--create", menuPath,
                    "--type", "raw",
                    "--description", "Futureport82",
                    "--command", commandByPath[menuPath] ?? "",
                    "--mode", "install"
                ],
                onOutput: onOutput
            )
            if exitCode != 0 {
                createOK = false
            }
        }

        let installExitCode = try? await ShellService.run(
            executable: cxmenuBin,
            arguments: ["--bottle", bottlePath.path, "--install"],
            onOutput: onOutput
        )
        if createOK && installExitCode == 0 {
            onOutput("Registered CrossOver application entries (Start Menu + Desktop).\n")
        } else {
            onOutput("Warning: Could not fully register CrossOver application menu entry.\n")
        }

        _ = try? await ShellService.run(
            executable: cxbottleBin,
            arguments: ["--bottle", bottlePath.path, "--install"],
            onOutput: onOutput
        )
    }

    private static func ensureMenuWrapperScripts(bottlePath: URL, winePath: String) -> (startMenu: URL, desktop: URL) {
        let fm = FileManager.default
        let cxmenuDir = bottlePath.appendingPathComponent("desktopdata/cxmenu")
        let startDir = cxmenuDir.appendingPathComponent(
            "StartMenu.C^5E3A_users_crossover_AppData_Roaming_Microsoft_Windows_Start^2BMenu/Programs"
        )
        let desktopDir = cxmenuDir.appendingPathComponent("Desktop.C^5E3A_users_crossover_Desktop")

        try? fm.createDirectory(at: startDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: desktopDir, withIntermediateDirectories: true)

        let startScript = startDir.appendingPathComponent("Futureport82.lnk")
        let desktopScript = desktopDir.appendingPathComponent("Futureport82.lnk")
        let escapedWinePath = winePath.replacingOccurrences(of: "\\", with: "\\\\")
        let script = """
        #!/bin/sh
        exec "\(cxstartBin.path)" --bottle "\(bottlePath.path)" "\(escapedWinePath)" "$@"
        """

        try? script.write(to: startScript, atomically: true, encoding: .utf8)
        try? script.write(to: desktopScript, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: startScript.path)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: desktopScript.path)

        return (startScript, desktopScript)
    }
}
