import AppKit
import CoreGraphics

// MARK: - Private API

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(
    _ config: CGDisplayConfigRef,
    _ display: CGDirectDisplayID,
    _ enabled: Bool
) -> CGError

// MARK: - Display helpers

let kBuiltInFallbackID: CGDirectDisplayID = 1

func getOnlineDisplays() -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetOnlineDisplayList(16, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

func findBuiltInDisplay() -> CGDirectDisplayID? {
    return getOnlineDisplays().first { CGDisplayIsBuiltin($0) != 0 }
}

func hasExternalDisplays() -> Bool {
    return getOnlineDisplays().contains { CGDisplayIsBuiltin($0) == 0 }
}

func setDisplayEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) -> Bool {
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success,
          let config = config else { return false }

    guard CGSConfigureDisplayEnabled(config, displayID, enabled) == .success else {
        CGCancelDisplayConfiguration(config)
        return false
    }

    return CGCompleteDisplayConfiguration(config, .permanently) == .success
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!

    // Track state
    var builtInDisabled = false
    var lastBuiltInID: CGDirectDisplayID = kBuiltInFallbackID

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — this is a menu bar-only app
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Display Toggle")
        }

        // Build menu
        let menu = NSMenu()

        toggleItem = NSMenuItem(title: "Turn Off Built-in Display", action: #selector(toggleDisplay), keyEquivalent: "d")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Remember built-in display ID
        if let builtIn = findBuiltInDisplay() {
            lastBuiltInID = builtIn
        }

        // Register for display configuration changes.
        // This fires when displays are connected/disconnected.
        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo!).takeUnretainedValue()
            delegate.handleDisplayChange(displayID: displayID, flags: flags)
        }, Unmanaged.passUnretained(self).toOpaque())

        updateMenuState()
    }

    func handleDisplayChange(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        // We only care about the "done" phase of a reconfiguration
        guard flags.contains(.beginConfigurationFlag) == false else { return }

        // If built-in is disabled and all externals just disappeared, recover
        if builtInDisabled && !hasExternalDisplays() {
            NSLog("External displays gone — restoring built-in display")
            if setDisplayEnabled(lastBuiltInID, enabled: true) {
                builtInDisabled = false
            }
        }

        // Update built-in ID if it reappeared
        if let builtIn = findBuiltInDisplay() {
            lastBuiltInID = builtIn
        }

        DispatchQueue.main.async { self.updateMenuState() }
    }

    func updateMenuState() {
        if builtInDisabled {
            toggleItem.title = "Turn On Built-in Display"
            statusItem.button?.image = NSImage(systemSymbolName: "macbook.slash", accessibilityDescription: "Built-in display off")
        } else {
            toggleItem.title = "Turn Off Built-in Display"
            statusItem.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Display Toggle")
        }

        // Disable the toggle if no externals connected and built-in is on
        toggleItem.isEnabled = builtInDisabled || hasExternalDisplays()
    }

    @objc func toggleDisplay() {
        if builtInDisabled {
            // Re-enable
            if setDisplayEnabled(lastBuiltInID, enabled: true) {
                builtInDisabled = false
                NSLog("Built-in display enabled")
            } else {
                showAlert("Failed to re-enable built-in display. Try closing and reopening the laptop lid.")
            }
        } else {
            // Disable
            guard hasExternalDisplays() else {
                showAlert("No external display connected. Connect one first or you'll have no display output.")
                return
            }

            if let builtIn = findBuiltInDisplay() {
                lastBuiltInID = builtIn
            }

            if setDisplayEnabled(lastBuiltInID, enabled: false) {
                builtInDisabled = true
                NSLog("Built-in display disabled")
            } else {
                showAlert("Failed to disable built-in display. The private API may be blocked on this macOS version.")
            }
        }

        updateMenuState()
    }

    func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "BlackScreen"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        // Re-enable built-in display before quitting so user isn't stranded
        if builtInDisabled {
            _ = setDisplayEnabled(lastBuiltInID, enabled: true)
        }
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
