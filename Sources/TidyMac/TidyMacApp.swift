// TidyMac — by M.Alshmmari

import SwiftUI

@main
struct TidyMacApp: App {
    @NSApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(organizer: app.organizer)
        } label: {
            Image(nsImage: AppMark.template)
        }
        .menuBarExtraStyle(.window)
    }
}

enum AppMark {
    /// The app's mark as a template image, so macOS tints it for light and dark mode.
    /// Used in the menu bar and on the "Tidy now" button.
    static let template: NSImage = {
        let icon = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)!
        icon.isTemplate = true
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let organizer = Organizer()
    private var tidyShortcut: Hotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        organizer.start()

        tidyShortcut = Hotkey(keyCode: Shortcut.keyCode, modifiers: Shortcut.modifiers) { [organizer] in
            Task { await organizer.tidyEverything() }
        }

        if Settings.isFirstLaunch() {
            // Registering a login item can take a while when macOS is busy; don't hold up the app for it.
            DispatchQueue.global(qos: .utility).async { LoginItem.set(true) }
            if Settings.screenshotsToFolder { ScreenshotLocation.useFolder() }
        }
    }
}
