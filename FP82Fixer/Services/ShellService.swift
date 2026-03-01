import Foundation

struct ShellService {

    static func run(
        executable: URL,
        arguments: [String] = [],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        inputString: String? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let dir = currentDirectory { process.currentDirectoryURL = dir }

        if let env = environment {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let inputPipe: Pipe?
        if inputString != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            inputPipe = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
            inputPipe = nil
        }

        if let handler = onOutput {
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                handler(str)
            }
        }

        let exitCode: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                if let handler = onOutput {
                    let remaining = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty, let str = String(data: remaining, encoding: .utf8) {
                        handler(str)
                    }
                }
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
                if let input = inputString, let data = input.data(using: .utf8) {
                    inputPipe?.fileHandleForWriting.write(data)
                    inputPipe?.fileHandleForWriting.closeFile()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }

        return exitCode
    }

    static func dismissWineDialogs() async {
        let script = """
        tell application "System Events"
            try
                repeat with proc in (processes whose name contains "regsvr32" or name contains "RegSvr32" or name contains "regsvr32.exe")
                    try
                        if exists (window 1 of proc) then
                            set frontmost of proc to true
                            delay 0.5
                            try
                                click button "OK" of window 1 of proc
                            on error
                                try
                                    keystroke return
                                on error
                                    keystroke (ASCII character 27)
                                end try
                            end try
                            delay 0.3
                        end if
                    end try
                end repeat
            end try
        end tell
        """

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                process.waitUntilExit()
                continuation.resume()
            }
        }
    }

    static func dismissDialogLoop() async {
        try? await Task.sleep(for: .seconds(3))
        for _ in 0..<5 {
            guard !Task.isCancelled else { return }
            await dismissWineDialogs()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Runs a wine command in the background with concurrent dialog dismissal.
    /// Output is captured and forwarded to the onOutput handler.
    static func runWineWithDialogDismissal(
        bottleName: String,
        bottlePath: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        onOutput: @Sendable @escaping (String) -> Void
    ) async {
        let wineBin = URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine")

        let process = Process()
        process.executableURL = wineBin
        process.arguments = ["--bottle", bottleName] + arguments

        var env = ProcessInfo.processInfo.environment
        env["WINEDEBUG"] = "-all"
        env["WINEPREFIX"] = bottlePath.path
        process.environment = env

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        if let dir = currentDirectory {
            process.currentDirectoryURL = dir
        }

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            onOutput(str)
        }

        guard (try? process.run()) != nil else {
            onOutput("Warning: Failed to start wine command\n")
            return
        }

        let dismissTask = Task.detached {
            await dismissDialogLoop()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                process.waitUntilExit()
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty, let str = String(data: remaining, encoding: .utf8) {
                    onOutput(str)
                }
                continuation.resume()
            }
        }

        dismissTask.cancel()
    }
}
