import SwiftUI
import AppKit

@main
struct FP82FixerApp: App {

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let iconURL = Bundle.module.url(forResource: "app-icon", withExtension: "png", subdirectory: "Images"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = Self.applyIconMask(to: icon)
        }
    }

    private static func applyIconMask(to source: NSImage) -> NSImage {
        let size = NSSize(width: 1024, height: 1024)
        let cornerRadius: CGFloat = size.width * 0.2237
        let result = NSImage(size: size)
        result.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    var body: some Scene {
        WindowGroup("Futureport82 Fixer") {
            ContentView()
        }
        .defaultSize(width: 750, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
