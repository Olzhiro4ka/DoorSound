import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var appState: AppState!

    // Menu item tags
    let tagEnable = 100
    let tagAbout = 200
    let tagStartup = 250
    let tagSensor = 260
    let tagQuit = 300

    static let currentVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "DoorSound") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "DoorSound"
            }
        }

        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let enableItem = NSMenuItem(title: "Sound Enabled", action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        enableItem.target = self
        enableItem.tag = tagEnable
        enableItem.isEnabled = true
        enableItem.state = appState.isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        // Volume slider
        let volumeLabel = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeLabel.isEnabled = false
        menu.addItem(volumeLabel)

        let slider = NSSlider(value: Double(appState.volume), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        slider.setAccessibilityLabel("Volume")
        slider.isEnabled = appState.isEnabled
        slider.frame = NSRect(x: 20, y: 0, width: 180, height: 24)
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        sliderView.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        let sensorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        sensorItem.tag = tagSensor
        sensorItem.isEnabled = false
        menu.addItem(sensorItem)
        menu.addItem(NSMenuItem.separator())

        let startupItem = NSMenuItem(title: "Start at Login", action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        startupItem.target = self
        startupItem.tag = tagStartup
        startupItem.isEnabled = true
        startupItem.state = isLoginItemEnabled() ? .on : .off
        menu.addItem(startupItem)

        let aboutItem = NSMenuItem(title: "About DoorSound", action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.tag = tagAbout
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit DoorSound", action: #selector(menuItemClicked(_:)), keyEquivalent: "q")
        quitItem.target = self
        quitItem.tag = tagQuit
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.item(withTag: tagSensor) {
            item.title = appState.sensorUnavailable ? "Lid sensor unavailable on this Mac" : "Lid sensor connected"
        }
        if let item = menu.item(withTag: tagStartup) {
            item.state = isLoginItemEnabled() ? .on : .off
        }
    }

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        switch sender.tag {
        case tagEnable:
            appState.isEnabled.toggle()
            if let button = statusItem.button {
                let name = appState.isEnabled ? "door.left.hand.open" : "door.left.hand.closed"
                if let img = NSImage(systemSymbolName: name, accessibilityDescription: "DoorSound") {
                    img.isTemplate = true
                    button.image = img
                }
            }
            buildMenu()

        case tagStartup:
            toggleLoginItem()
            buildMenu()

        case tagAbout:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(options: [
                .applicationName: "DoorSound",
                .applicationVersion: AppDelegate.currentVersion,
                .credits: NSAttributedString(string: "Makes your MacBook lid sound like a squeaky door.")
            ])

        case tagQuit:
            NSApplication.shared.terminate(nil)

        default:
            break
        }
    }

    func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    NSLog("[DoorSound] Login item disabled")
                } else {
                    try SMAppService.mainApp.register()
                    NSLog("[DoorSound] Login item enabled")
                }
            } catch {
                NSLog("[DoorSound] Failed to toggle login item: %@", error.localizedDescription)
                let alert = NSAlert(error: error)
                alert.messageText = "Could not change Start at Login"
                alert.runModal()
            }
        }
    }

    @objc func volumeChanged(_ sender: NSSlider) {
        appState.volume = Float(sender.doubleValue)
    }


}
