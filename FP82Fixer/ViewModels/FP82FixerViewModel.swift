import SwiftUI
import AppKit

@MainActor
@Observable
class FP82FixerViewModel {

    // MARK: - CrossOver state

    var crossOverFound = false
    var crossOverStatusMessage = "Checking for CrossOver..."
    var crossOverStatusOK = false

    // MARK: - Bottles

    var bottles: [Bottle] = []
    var selectedBottleID: String?

    // MARK: - Executable

    var executablePath = ""

    // MARK: - Options

    var addToBottle = true

    // MARK: - Fix state

    enum FixResult { case none, success, failed }

    var isFixRunning = false
    var fixResult: FixResult = .none
    var outputLines: [String] = []

    // MARK: - Computed

    var canApplyFix: Bool {
        crossOverFound
            && selectedBottleID != nil
            && !executablePath.isEmpty
            && FileManager.default.fileExists(atPath: executablePath)
            && !isFixRunning
    }

    var selectedBottle: Bottle? {
        bottles.first { $0.id == selectedBottleID }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    // MARK: - Init

    init() {
        detectCrossOver()
        refreshBottles()
        requestPermissionsOnFirstLaunch()
    }

    // MARK: - CrossOver Detection

    func detectCrossOver() {
        let (found, path) = CrossOverService.detect()
        crossOverFound = found
        if found {
            crossOverStatusMessage = "CrossOver found at: \(path)"
            crossOverStatusOK = true
        } else {
            crossOverStatusMessage = "CrossOver not found at /Applications/CrossOver.app"
            crossOverStatusOK = false
        }
    }

    // MARK: - Bottle Management

    func refreshBottles() {
        bottles = CrossOverService.listBottles()
        if let selected = selectedBottleID, !bottles.contains(where: { $0.id == selected }) {
            selectedBottleID = nil
        }
    }

    func createBottle() {
        let alert = NSAlert()
        alert.messageText = "Create New Bottle"
        alert.informativeText = "Enter bottle name:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = "futureport82"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        appendOutput("Creating bottle: \(name)...\n")

        Task {
            do {
                try await CrossOverService.createBottle(name: name) { text in
                    Task { @MainActor [weak self] in self?.appendOutput(text) }
                }
                appendOutput("Bottle '\(name)' created successfully!\n")
                refreshBottles()
                selectedBottleID = name
            } catch {
                appendOutput("Error creating bottle: \(error.localizedDescription)\n")
            }
        }
    }

    func removeSelectedBottle() {
        guard let bottle = selectedBottle else { return }

        let alert = NSAlert()
        alert.messageText = "Confirm Removal"
        alert.informativeText = "Are you sure you want to remove bottle '\(bottle.name)'?\n\nThis action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                try await CrossOverService.removeBottle(name: bottle.name) { text in
                    Task { @MainActor [weak self] in self?.appendOutput(text) }
                }
                appendOutput("Bottle '\(bottle.name)' removed successfully.\n")
                refreshBottles()
            } catch {
                appendOutput("Error removing bottle: \(error.localizedDescription)\n")
            }
        }
    }

    // MARK: - Executable Selection

    func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Select Futureport82 Executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.item]

        if panel.runModal() == .OK, let url = panel.url {
            executablePath = url.path
        }
    }

    // MARK: - Apply Fix

    func applyFix() {
        guard let bottle = selectedBottle else { return }

        do {
            try MediaFoundationService.verifyResources()
        } catch {
            showError("Missing Resources", detail: error.localizedDescription)
            return
        }

        let confirm = NSAlert()
        confirm.messageText = "Apply Media Foundation Fix?"
        confirm.informativeText = """
        Bottle: \(bottle.name)
        Executable: \(executablePath)

        During the fix, CrossOver may show dialogs.
        Watch the dock and click the CrossOver icon to dismiss them.
        """
        confirm.alertStyle = .informational
        confirm.addButton(withTitle: "Apply Fix")
        confirm.addButton(withTitle: "Cancel")

        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let permissions = PermissionService.checkRequiredPermissions(prompt: true)
        guard permissions.allGranted else {
            showMissingPermissionsAlert(status: permissions)
            appendOutput("Permissions required before running the fix.\n")
            if !permissions.accessibilityTrusted {
                appendOutput("- Enable Accessibility for FP82Fixer in System Settings -> Privacy & Security -> Accessibility.\n")
            }
            if !permissions.appleEventsTrusted {
                appendOutput("- Allow FP82Fixer to control System Events when prompted (Automation).\n")
            }
            appendOutput("After granting, retry Apply Fix.\n\n")
            return
        }

        runFix(bottle: bottle)
    }

    private func runFix(bottle: Bottle) {
        isFixRunning = true
        fixResult = .none
        outputLines = []
        appendOutput("Starting media foundation fix...\n")
        appendOutput("Bottle: \(bottle.name)\n")
        appendOutput("Executable: \(executablePath)\n\n")

        Task {
            do {
                try await MediaFoundationService.applyFix(
                    bottleName: bottle.name,
                    bottlePath: bottle.path,
                    executablePath: URL(fileURLWithPath: executablePath)
                ) { text in
                    Task { @MainActor [weak self] in self?.appendOutput(text) }
                }

                if addToBottle {
                    appendOutput("\nAdding Futureport82 to bottle as application...\n")
                    try await BottleApplicationService.addToBottle(
                        executablePath: URL(fileURLWithPath: executablePath),
                        bottleName: bottle.name,
                        bottlePath: bottle.path
                    ) { text in
                        Task { @MainActor [weak self] in self?.appendOutput(text) }
                    }
                }

                appendOutput("\n✅ Fix completed successfully!\n")
                fixResult = .success
            } catch is CancellationError {
                appendOutput("\n⚠️ Fix was cancelled.\n")
                fixResult = .failed
                await cleanupWineserver(bottle: bottle)
            } catch {
                appendOutput("\n❌ Error: \(error.localizedDescription)\n")
                fixResult = .failed
                await cleanupWineserver(bottle: bottle)
            }
            isFixRunning = false
        }
    }

    // MARK: - Output

    func appendOutput(_ text: String) {
        for line in text.components(separatedBy: "\n") where !line.isEmpty {
            outputLines.append(line)
        }
    }

    func clearOutput() {
        outputLines = []
    }

    private func cleanupWineserver(bottle: Bottle) async {
        appendOutput("\n🧹 Cleaning up wineserver after error...\n")
        await MediaFoundationService.shutdownWineserver(
            bottleName: bottle.name,
            bottlePath: bottle.path
        ) { text in
            Task { @MainActor [weak self] in self?.appendOutput(text) }
        }
    }

    // MARK: - Helpers

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func requestPermissionsOnFirstLaunch() {
        let firstLaunchKey = "did_request_permissions_prompt"
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: firstLaunchKey) == false else { return }

        PermissionService.requestStartupPrompts()
        defaults.set(true, forKey: firstLaunchKey)
    }

    private func showMissingPermissionsAlert(status: PermissionService.Status) {
        var missing: [String] = []
        if !status.accessibilityTrusted {
            missing.append("Accessibility")
        }
        if !status.appleEventsTrusted {
            missing.append("Automation (System Events)")
        }

        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = """
        FP82Fixer needs \(missing.joined(separator: " and ")) to auto-dismiss Wine/RegSvr32 dialogs.

        Open System Settings -> Privacy & Security and grant these permissions, then retry.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
