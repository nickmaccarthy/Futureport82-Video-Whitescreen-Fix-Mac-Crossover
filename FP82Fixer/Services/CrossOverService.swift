import Foundation

struct CrossOverService {

    static let defaultCrossOverPath = "/Applications/CrossOver.app"
    static let bottlesDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CrossOver/Bottles")

    private static let cxbottle = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxbottle"

    static func detect() -> (found: Bool, path: String) {
        let fm = FileManager.default
        let appExists = fm.fileExists(atPath: defaultCrossOverPath)
        let bottleToolExists = fm.fileExists(atPath: cxbottle)
        return (appExists && bottleToolExists, appExists ? defaultCrossOverPath : "")
    }

    static func listBottles() -> [Bottle] {
        let fm = FileManager.default
        let dir = bottlesDirectory

        guard fm.fileExists(atPath: dir.path) else { return [] }

        do {
            let contents = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .map { Bottle(name: $0.lastPathComponent, path: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            return []
        }
    }

    static func createBottle(
        name: String,
        onOutput: @Sendable @escaping (String) -> Void
    ) async throws {
        let exitCode = try await ShellService.run(
            executable: URL(fileURLWithPath: cxbottle),
            arguments: [
                "--bottle", name,
                "--description", "Bottle for futureport82",
                "--template", "win10_64",
                "--create",
                "--param", "EnvironmentVariables:CX_GRAPHICS_BACKEND=d3dmetal"
            ],
            onOutput: onOutput
        )
        if exitCode != 0 {
            throw FixerError.bottleCreationFailed(name)
        }
    }

    static func removeBottle(
        name: String,
        onOutput: @Sendable @escaping (String) -> Void
    ) async throws {
        let exitCode = try await ShellService.run(
            executable: URL(fileURLWithPath: cxbottle),
            arguments: ["--bottle", name, "--delete", "--force"],
            onOutput: onOutput
        )
        if exitCode != 0 {
            throw FixerError.bottleRemovalFailed(name)
        }
    }
}

enum FixerError: LocalizedError {
    case crossOverNotFound
    case bottleCreationFailed(String)
    case bottleRemovalFailed(String)
    case resourcesNotFound
    case fixScriptFailed(Int32)
    case executableNotFound(String)

    var errorDescription: String? {
        switch self {
        case .crossOverNotFound:
            return "CrossOver not found at /Applications/CrossOver.app"
        case .bottleCreationFailed(let name):
            return "Failed to create bottle '\(name)'"
        case .bottleRemovalFailed(let name):
            return "Failed to remove bottle '\(name)'"
        case .resourcesNotFound:
            return "Bundled fix resources not found"
        case .fixScriptFailed(let code):
            return "Fix failed with exit code \(code)"
        case .executableNotFound(let path):
            return "Executable not found at \(path)"
        }
    }
}
