import Foundation

enum ResourceBundleLocator {
    private static let expectedBundleName = "FP82Fixer_FP82Fixer.bundle"

    static let bundle: Bundle = {
        if let resolved = resolveBundle() {
            return resolved
        }

        let searched = candidateDirectories()
            .map(\.path)
            .joined(separator: ", ")
        Swift.fatalError("could not load resource bundle \(expectedBundleName); searched: \(searched)")
    }()

    static func url(forResource name: String, withExtension ext: String?, subdirectory subpath: String? = nil) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: subpath)
    }

    private static func resolveBundle() -> Bundle? {
        let fm = FileManager.default

        for dir in candidateDirectories() {
            let exact = dir.appendingPathComponent(expectedBundleName)
            if let bundle = Bundle(path: exact.path), hasExpectedContents(bundle: bundle, fileManager: fm) {
                return bundle
            }

            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries where entry.pathExtension == "bundle" {
                if let bundle = Bundle(path: entry.path), hasExpectedContents(bundle: bundle, fileManager: fm) {
                    return bundle
                }
            }
        }

        return nil
    }

    private static func hasExpectedContents(bundle: Bundle, fileManager: FileManager) -> Bool {
        // Prefer the known fix script as a strong signal this is the app's resources.
        if fileManager.fileExists(atPath: bundle.bundleURL.appendingPathComponent("FixResources/mf-fix-cx.sh").path) {
            return true
        }
        // Fallback for future packaging changes.
        return fileManager.fileExists(atPath: bundle.bundleURL.appendingPathComponent("Images/background.png").path)
    }

    private static func candidateDirectories() -> [URL] {
        var dirs: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            dirs.append(resourceURL)
        }

        dirs.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources"))
        dirs.append(Bundle.main.bundleURL)

        if let executable = CommandLine.arguments.first, !executable.isEmpty {
            dirs.append(URL(fileURLWithPath: executable).deletingLastPathComponent())
        }

        if let finderResourceURL = Bundle(for: BundleFinder.self).resourceURL {
            dirs.append(finderResourceURL)
        }

        // Preserve order while removing duplicates.
        var seen: Set<String> = []
        return dirs.filter { seen.insert($0.path).inserted }
    }
}

private final class BundleFinder {}
