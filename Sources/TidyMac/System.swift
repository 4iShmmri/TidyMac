// TidyMac — by M.Alshmmari
//
// The two places TidyMac touches macOS itself: where screenshots are saved,
// and starting at login.

import Foundation
import ServiceManagement

enum ScreenshotLocation {
    private static let domain = "com.apple.screencapture"

    static var isInFolder: Bool {
        UserDefaults(suiteName: domain)?.string(forKey: "location") == Places.screenshots.path
    }

    /// Tells macOS to save new screenshots straight into Desktop/Screenshots.
    static func useFolder() {
        try? FileManager.default.createDirectory(at: Places.screenshots, withIntermediateDirectories: true)
        run("/usr/bin/defaults", "write", domain, "location", Places.screenshots.path)
        run("/usr/bin/killall", "SystemUIServer")
    }

    /// Puts macOS back to its default: screenshots land on the Desktop.
    static func useDesktop() {
        run("/usr/bin/defaults", "delete", domain, "location")
        run("/usr/bin/killall", "SystemUIServer")
    }

    private static func run(_ tool: String, _ arguments: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}

enum LoginItem {
    static var isOn: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("TidyMac couldn't change the login item: \(error.localizedDescription)")
        }
    }
}
