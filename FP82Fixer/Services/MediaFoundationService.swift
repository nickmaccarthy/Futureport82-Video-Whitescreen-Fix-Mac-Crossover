import Foundation

struct MediaFoundationService {

    private static let wineBin = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    )

    static func resourceDirectory() throws -> URL {
        guard let url = ResourceBundleLocator.url(forResource: "FixResources", withExtension: nil) else {
            throw FixerError.resourcesNotFound
        }
        return url
    }

    static func verifyResources() throws {
        let dir = try resourceDirectory()
        let fm = FileManager.default
        let required = ["mf-fix-cx.sh", "system32", "syswow64", "mf.reg", "wmf.reg", "mfplat.dll"]
        let missing = required.filter { !fm.fileExists(atPath: dir.appendingPathComponent($0).path) }
        if !missing.isEmpty {
            throw FixerError.resourcesNotFound
        }
    }

    // MARK: - Main fix — calls the proven bash script

    /// Runs the fix by calling `mf-fix-cx.sh` with the same arguments
    /// the Python GUI uses. This is the proven, battle-tested approach.
    static func applyFix(
        bottleName: String,
        bottlePath: URL,
        executablePath: URL,
        onOutput: @Sendable @escaping (String) -> Void
    ) async throws {
        let resourceDir = try resourceDirectory()
        let scriptPath = resourceDir.appendingPathComponent("mf-fix-cx.sh")

        onOutput("⚠️  IMPORTANT: Watch for CrossOver dialogs!\n")
        onOutput("   During the fix, CrossOver may show 'OK' dialogs in the dock.\n")
        onOutput("   Click on the CrossOver icon in the dock to see and dismiss them.\n\n")
        onOutput("Script: \(scriptPath.path)\n")
        onOutput("Resource dir: \(resourceDir.path)\n")
        onOutput("Bottle: \(bottlePath.path)\n")
        onOutput("Executable: \(executablePath.path)\n\n")

        // Determine the exe directory (the script expects a directory or file path)
        let exeArg: String
        let fm = FileManager.default
        if fm.fileExists(atPath: executablePath.path) {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: executablePath.path, isDirectory: &isDir)
            exeArg = isDir.boolValue
                ? executablePath.path
                : executablePath.path
        } else {
            throw FixerError.executableNotFound(executablePath.path)
        }

        // Build environment matching what the Python GUI sets
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["MF_FIX_RESOURCE_DIR"] = resourceDir.path

        // Run: /bin/bash mf-fix-cx.sh -e <exe_path> <bottle_path>
        // Matches: subprocess.Popen(["/bin/bash", self.script_path, "-e", self.exe_path, self.bottle_dir], ...)
        let exitCode = try await ShellService.run(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [scriptPath.path, "-e", exeArg, bottlePath.path],
            currentDirectory: resourceDir,
            environment: env,
            onOutput: onOutput
        )

        if exitCode != 0 {
            throw FixerError.fixScriptFailed(exitCode)
        }

        onOutput("\n✅ Media Foundation fix applied successfully!\n")
    }

    // MARK: - Wineserver cleanup

    static func shutdownWineserver(
        bottleName: String,
        bottlePath: URL,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        var env = ProcessInfo.processInfo.environment
        env["WINEDEBUG"] = "-all"
        env["WINEPREFIX"] = bottlePath.path

        _ = try? await ShellService.run(
            executable: wineBin,
            arguments: ["--bottle", bottleName, "--cx-app", "wineserver", "-k"],
            environment: env,
            onOutput: onOutput
        )
        try? await Task.sleep(for: .seconds(2))
        onOutput("  Wineserver shut down.\n")
    }
}
