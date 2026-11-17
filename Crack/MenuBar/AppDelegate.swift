import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var appState: AppState!

    // Menu item tags
    let tagEnable = 100
    let tagAbout = 200
    let tagStartup = 250
    let tagQuit = 300
    let tagSoundBase = 1000

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

        let enableItem = NSMenuItem(title: appState.isEnabled ? "✅ Enabled" : "❌ Disabled", action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        enableItem.target = self
        enableItem.tag = tagEnable
        enableItem.isEnabled = true
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        // Volume slider
        let volumeLabel = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeLabel.isEnabled = false
        menu.addItem(volumeLabel)

        let slider = NSSlider(value: Double(appState.volume), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        slider.frame = NSRect(x: 20, y: 0, width: 180, height: 24)
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        sliderView.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        // Sound picker submenu
        let sounds = appState.availableSounds
        if sounds.count > 1 {
            let soundMenu = NSMenu()
            for (index, sound) in sounds.enumerated() {
                let item = NSMenuItem(title: sound.capitalized, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
                item.target = self
                item.tag = tagSoundBase + index
                item.isEnabled = true
                item.state = sound == appState.selectedSound ? .on : .off
                soundMenu.addItem(item)
            }
            let soundItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
            soundItem.submenu = soundMenu
            menu.addItem(soundItem)
            menu.addItem(NSMenuItem.separator())
        }

        if appState.sensorUnavailable {
            let item = NSMenuItem(title: "Lid sensor unavailable", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

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
            if sender.tag >= tagSoundBase {
                let index = sender.tag - tagSoundBase
                let sounds = appState.availableSounds
                if index >= 0, index < sounds.count {
                    appState.selectedSound = sounds[index]
                    buildMenu()
                }
            }
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
            }
        }
    }

    @objc func volumeChanged(_ sender: NSSlider) {
        appState.volume = Float(sender.doubleValue)
    }


}
