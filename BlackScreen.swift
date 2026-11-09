import AppKit
import CoreGraphics
import IOKit

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

// Reads the lid state from the power management service. Desktop Macs have no
// lid, so the property is missing and this returns false.
func isLidClosed() -> Bool {
    let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard rootDomain != 0 else { return false }
    defer { IOObjectRelease(rootDomain) }
    let state = IORegistryEntryCreateCFProperty(
        rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue()
    return (state as? Bool) ?? false
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

// CoreGraphics calls this C callback on a thread Swift can't verify, so it
// only hops to the main actor, where all app state lives.
nonisolated func displayReconfigured(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    // We only care about the "done" phase of a reconfiguration
    guard !flags.contains(.beginConfigurationFlag) else { return }
    Task { @MainActor in
        (NSApp.delegate as? AppDelegate)?.handleDisplayChange()
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
            button.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "BlackScreen")
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

        // Recover from a crash or force quit that left the built-in display
        // off. A disabled display drops out of the online list, so try the
        // usual built-in ID. Skipped with the lid closed, where a missing
        // built-in display is expected.
        if findBuiltInDisplay() == nil && !isLidClosed() {
            if setDisplayEnabled(kBuiltInFallbackID, enabled: true) {
                NSLog("Built-in display was missing at launch, re-enabled it")
            }
        }

        // Remember built-in display ID
        if let builtIn = findBuiltInDisplay() {
            lastBuiltInID = builtIn
        }

        // Register for display configuration changes.
        // This fires when displays are connected/disconnected.
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, nil)

        updateMenuState()
    }

    func handleDisplayChange() {
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

        updateMenuState()
    }

    func updateMenuState() {
        if builtInDisabled {
            toggleItem.title = "Turn On Built-in Display"
            statusItem.button?.image = NSImage(systemSymbolName: "macbook.slash", accessibilityDescription: "Built-in display off")
        } else {
            toggleItem.title = "Turn Off Built-in Display"
            statusItem.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "BlackScreen")
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

    // Runs on Quit, logout, restart, and shutdown. Re-enable the built-in
    // display so the user isn't stranded.
    func applicationWillTerminate(_ notification: Notification) {
        if builtInDisabled {
            _ = setDisplayEnabled(lastBuiltInID, enabled: true)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
