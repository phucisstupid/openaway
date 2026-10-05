import AppKit
import OpenAwayCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private(set) var model: AppModel!
    private var statusItem: NSStatusItem?
    private var dashboard: NSWindow?
    private var breakWindows: [NSWindow] = []
    private var reminderPanel: NSPanel?
    private var previousApplication: NSRunningApplication?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var localObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var screenSignature = ""
    private var rebuildingWindows = false
    private var smokeTesting = false
    private var reminderPresented = false
    private var reminderAnimation = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let smoke = ProcessInfo.processInfo.arguments.contains("--smoke-test")
        let interactiveSmoke = smoke && ProcessInfo.processInfo.arguments.contains("--interactive")
        smokeTesting = smoke
        model = AppModel(persists: !smoke)
        model.coordinator = self
        if smoke {
            model.settings.idlePauseEnabled = false
            model.settings.soundEnabled = false
            model.settings.postureReminderEnabled = false
            model.settings.pauseForMeetings = false
            model.settings.pauseForVideo = false
        }
        installStatusItem()
        installMainMenu()
        installObservers()
        applyAppearance()
        model.begin()
        if interactiveSmoke {
            model.stop()
            model.selectedPage = "general"
        }
        // The first launch is discoverable; closing this window leaves the timer running.
        if !UserDefaults.standard.bool(forKey: "hasLaunched.v1") || ProcessInfo.processInfo.arguments.contains("--show-dashboard") || smoke {
            showDashboard()
            if !smoke { UserDefaults.standard.set(true, forKey: "hasLaunched.v1") }
        }
        if smoke && !interactiveSmoke {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.runSmokeTest() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        closeBreakWindows(restoreApplication: false)
        reminderPanel?.close()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        localObservers.forEach { NotificationCenter.default.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    func showDashboard() {
        if dashboard == nil {
            let window = DashboardWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 750),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "OpenAway"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            // An empty native toolbar gives the traffic lights a comfortable inset.
            window.toolbar = NSToolbar(identifier: "OpenAwayWindowControls")
            window.toolbarStyle = .unified
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 850, height: 620)
            window.isReleasedWhenClosed = false
            let frameName = "OpenAwayDashboardExpanded"
            if !smokeTesting { window.setFrameAutosaveName(frameName) }
            let controller = NSSplitViewController()
            controller.splitView.isVertical = true
            controller.splitView.dividerStyle = .thin
            let sidebar = NSSplitViewItem(sidebarWithViewController: NSHostingController(rootView: DashboardSidebarView(model: model)))
            sidebar.minimumThickness = 217
            sidebar.maximumThickness = 217
            sidebar.canCollapse = false
            sidebar.allowsFullHeightLayout = true
            sidebar.titlebarSeparatorStyle = .none
            controller.addSplitViewItem(sidebar)
            let detail = NSSplitViewItem(viewController: NSHostingController(rootView: DashboardView(model: model)))
            detail.minimumThickness = 590
            controller.addSplitViewItem(detail)
            window.contentViewController = controller
            window.delegate = self
            if smokeTesting || !window.setFrameUsingName(frameName) {
                let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 960)
                let size = NSSize(width: min(1200, visible.width - 24), height: min(900, visible.height - 24))
                window.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                                       width: size.width, height: size.height), display: false)
            }
            dashboard = window
        }
        dashboard?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applyAppearance() {
        switch model.settings.appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    func synchronizeBreakWindows() {
        guard !rebuildingWindows else { return }
        let shouldShow = model.isPreviewing || model.engine.phase == .resting
        guard shouldShow else {
            if !breakWindows.isEmpty { closeBreakWindows(restoreApplication: true) }
            return
        }
        let signature = NSScreen.screens.map { "\($0.frame)" }.joined(separator: "|")
        if !breakWindows.isEmpty && signature == screenSignature { return }
        rebuildingWindows = true
        defer { rebuildingWindows = false }
        if breakWindows.isEmpty { previousApplication = NSWorkspace.shared.frontmostApplication }
        else { closeBreakWindows(restoreApplication: false) }
        screenSignature = signature
        reminderPanel?.orderOut(nil)
        for screen in NSScreen.screens {
            let window = BreakWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.hasShadow = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: BreakOverlayView(model: model))
            window.onEscape = { [weak self] isRepeat in self?.model.handleEscape(isRepeat: isRepeat) }
            window.setFrame(screen.frame, display: true)
            breakWindows.append(window)
            window.orderFrontRegardless()
        }
        breakWindows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeBreakWindows(restoreApplication: Bool) {
        let windows = breakWindows
        breakWindows = []
        screenSignature = ""
        windows.forEach { $0.orderOut(nil); $0.close() }
        if restoreApplication {
            let previous = previousApplication
            previousApplication = nil
            if NSApp.isActive, let previous, previous.processIdentifier != ProcessInfo.processInfo.processIdentifier,
               !previous.isTerminated { previous.activate(options: [.activateIgnoringOtherApps]) }
        }
    }

    func synchronizeReminder() {
        let mayPresent = !model.isPreviewing && model.engine.phase != .resting && (model.isReminderPreview || model.engine.phase != .paused)
        let shouldShow = (model.isShowingHeadsUp || model.reminderText != nil) && mayPresent
        if shouldShow, let panel = reminderPanel { sizeReminderPanel(panel) }
        guard shouldShow != reminderPresented else { return }
        reminderPresented = shouldShow
        reminderAnimation += 1
        let animationID = reminderAnimation
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldShow else {
            guard let panel = reminderPanel else { return }
            // Automatic pauses and breaks suppress the HUD immediately.
            if !mayPresent || smokeTesting { panel.orderOut(nil); return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.12 : 0.25
                panel.animator().alphaValue = 0
                if !reduceMotion { panel.animator().setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY + 10)) }
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor [weak self, weak panel] in
                    guard self?.reminderAnimation == animationID else { return }
                    panel?.orderOut(nil)
                }
            }
            return
        }
        if reminderPanel == nil {
            let panel = ReminderPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 180),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: WellnessReminderView(model: model))
            reminderPanel = panel
        }
        guard let panel = reminderPanel else { return }
        sizeReminderPanel(panel)
        guard let destination = reminderOrigin(for: panel) else { return }
        panel.setFrameOrigin(NSPoint(x: destination.x, y: destination.y + (reduceMotion || smokeTesting ? 0 : 12)))
        panel.alphaValue = smokeTesting ? 1 : 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = smokeTesting ? 0 : reduceMotion ? 0.12 : 0.3
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(destination)
        }
    }

    private func sizeReminderPanel(_ panel: NSPanel) {
        guard let size = panel.contentView?.fittingSize, size.width > 0, size.height > 0,
              panel.frame.size != size else { return }
        let center = panel.frame.midX
        let top = panel.frame.maxY
        panel.setFrame(NSRect(x: center - size.width / 2, y: top - size.height,
                              width: size.width, height: size.height), display: true)
    }

    private func reminderOrigin(for panel: NSPanel) -> NSPoint? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        return NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2,
                       y: screen.visibleFrame.maxY - panel.frame.height - 18)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "OpenAway")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusItem()
    }

    func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        if model.settings.showCountdownInMenuBar {
            let seconds = model.engine.remainingSeconds
            let time = String(format: "%d:%02d", seconds / 60, seconds % 60)
            button.title = model.engine.phase == .paused ? " Ⅱ" : model.isShowingHeadsUp && seconds == 0 ? " ···" : " \(time)"
        } else { button.title = "" }
        button.toolTip = model.engine.phase == .paused ? "OpenAway — \(model.engine.pauseReason ?? "Paused")" : "OpenAway — \(model.engine.phase == .resting ? "Time to rest" : "Your next moment of rest")"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title: String
        switch model.engine.phase {
        case .paused: title = model.engine.pauseReason ?? "Paused"
        case .resting: title = "Enjoy a moment away"
        case .preparing where model.engine.remainingSeconds == 0: title = "Waiting for a pause in your work"
        default: title = "Next break in \(String(format: "%d:%02d", model.engine.remainingSeconds / 60, model.engine.remainingSeconds % 60))"
        }
        let summary = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        addItem("Take a Break", action: #selector(takeBreak), key: "b", modifiers: [.command, .shift], to: menu)
        addItem("Take a Long Break", action: #selector(takeLongBreak), to: menu)
        if model.engine.phase == .resting || model.engine.phase == .preparing || model.isPreviewing {
            addItem(model.isPreviewing ? "Close Preview" : "Skip This Break", action: #selector(skip), to: menu)
        }
        menu.addItem(.separator())
        addItem(model.engine.phase == .paused ? "Resume" : "Pause", action: #selector(togglePause), key: "p", modifiers: [.command, .shift], to: menu)
        let pause = NSMenuItem(title: "Pause for…", action: nil, keyEquivalent: "")
        let pauseMenu = NSMenu()
        for minutes in [15, 30, 60] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(pauseFor(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            pauseMenu.addItem(item)
        }
        pause.submenu = pauseMenu
        menu.addItem(pause)
        let snooze = NSMenuItem(title: "Delay Next Break", action: nil, keyEquivalent: "")
        let snoozeMenu = NSMenu()
        for minutes in [5, 10, 15] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(snoozeFor(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            snoozeMenu.addItem(item)
        }
        snooze.submenu = snoozeMenu
        menu.addItem(snooze)
        menu.addItem(.separator())
        addItem("Settings…", action: #selector(openSettings), key: ",", to: menu)
        addItem("Quit OpenAway", action: #selector(quit), key: "q", to: menu)
    }

    private func installMainMenu() {
        let main = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu(title: "OpenAway")
        addItem("About OpenAway", action: #selector(openAbout), to: appMenu)
        addItem("Settings…", action: #selector(openSettings), key: ",", to: appMenu)
        appMenu.addItem(.separator())
        addItem("Take a Break", action: #selector(takeBreak), key: "b", modifiers: [.command, .shift], to: appMenu)
        addItem("Pause or Resume", action: #selector(togglePause), key: "p", modifiers: [.command, .shift], to: appMenu)
        appMenu.addItem(.separator())
        addItem("Quit OpenAway", action: #selector(quit), key: "q", to: appMenu)
        application.submenu = appMenu
        main.addItem(application)
        let edit = NSMenuItem()
        edit.submenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.submenu?.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        main.addItem(edit)
        let window = NSMenuItem()
        window.submenu = NSMenu(title: "Window")
        window.submenu?.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.submenu?.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(window)
        NSApp.mainMenu = main
    }

    private func addItem(_ title: String, action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = [.command], to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        menu.addItem(item)
    }

    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.model.activeApplicationChanged() }
        })
        for (name, asleep) in [(NSWorkspace.willSleepNotification, true), (NSWorkspace.didWakeNotification, false)] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.model.setSleeping(asleep) }
            })
        }
        for (name, asleep) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false)] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.model.setDisplaySleeping(asleep) }
            })
        }
        localObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.synchronizeBreakWindows()
                if let panel = self.reminderPanel, panel.isVisible, let origin = self.reminderOrigin(for: panel) {
                    panel.setFrameOrigin(origin)
                }
            }
        })
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributedObservers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.model.setLocked(locked) }
            })
        }
    }

    @objc private func openSettings() { model.selectedPage = "general"; showDashboard() }
    @objc private func openAbout() { model.selectedPage = "about"; showDashboard() }
    @objc private func takeBreak() { model.startBreak() }
    @objc private func takeLongBreak() { model.startBreak(kind: .long) }
    @objc private func skip() { model.skipBreak() }
    @objc private func togglePause() { model.togglePause() }
    @objc private func pauseFor(_ sender: NSMenuItem) { model.pause(minutes: sender.tag) }
    @objc private func snoozeFor(_ sender: NSMenuItem) { model.snooze(minutes: sender.tag) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func imageBlurSmokeCheck() -> Bool {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenAway-image-blur-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return false }
        let black = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
        let white = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
        for x in 0..<32 {
            for y in 0..<32 { bitmap.setColor(x < 16 ? black : white, atX: x, y: y) }
        }
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let source = directory.appendingPathComponent("Split.png")
            try data.write(to: source)
            let model = AppModel(persists: false, breakImageDirectory: directory.appendingPathComponent("Imported"))
            model.settings.breakTheme = "blurImage"
            try model.importBreakImage(from: source)
            func contrast() -> CGFloat? {
                let renderer = ImageRenderer(content: BreakBackgroundView(model: model).frame(width: 120, height: 80))
                renderer.scale = 1
                guard let image = renderer.cgImage else { return nil }
                let pixels = NSBitmapImageRep(cgImage: image)
                guard let left = pixels.colorAt(x: 50, y: 40), let right = pixels.colorAt(x: 70, y: 40) else { return nil }
                return abs(right.redComponent - left.redComponent)
            }
            model.settings.breakImageBlurRadius = 0
            guard let sharp = contrast(), sharp > 0.3 else { return false }
            model.settings.breakImageBlurRadius = 40
            guard let blurred = contrast(), blurred < sharp * 0.6 else { return false }
            model.settings.breakImageBlurRadius = 0
            guard let unblurred = contrast() else { return false }
            return abs(unblurred - sharp) < 0.01
        } catch {
            return false
        }
    }

    private func runSmokeTest() {
        var failures: [String] = []
        func check(_ value: Bool, _ label: String) { if !value { failures.append(label) } }
        check(dashboard?.isVisible == true, "dashboard visible")
        check(dashboard?.titlebarAppearsTransparent == true && dashboard?.titleVisibility == .hidden
              && dashboard?.toolbar?.items.isEmpty == true, "window controls merge into content without toolbar actions")
        let sidebar = (dashboard?.contentViewController as? NSSplitViewController)?.splitViewItems.first
        check(sidebar?.behavior == .sidebar && sidebar?.allowsFullHeightLayout == true,
              "AppKit owns the full-height native sidebar")
        dashboard?.contentView?.layoutSubtreeIfNeeded()
        check([NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].allSatisfy { type in
            guard let button = dashboard?.standardWindowButton(type), let view = sidebar?.viewController.view else { return false }
            return view.bounds.contains(view.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), from: button))
        }, "native window controls remain inside the sidebar")
        check(model.selectedPage == "general", "dashboard defaults to General")
        openSettings()
        check(model.selectedPage == "general" && DashboardView.pages.map(\.id) == ["general", "wellness", "appearance", "shortcuts", "insights", "about"],
              "settings opens General with Wellness Reminders directly below it")
        let statusMenu = NSMenu()
        menuNeedsUpdate(statusMenu)
        check(statusMenu.items.filter { $0.action == #selector(openSettings) }.count == 1
              && !statusMenu.items.contains { $0.title == "Open OpenAway" }
              && NSApp.mainMenu?.items.compactMap(\.submenu).allSatisfy { menu in
                  !menu.items.contains { $0.title == "Open OpenAway" }
              } == true, "menus keep Settings without redundant Open OpenAway commands")
        check(statusMenu.items.first { $0.action == #selector(togglePause) }?.title == "Pause",
              "active reminders show Pause in the status menu")
        check(AppModel.resetSettingsSmokeCheck(), "reset restores all preferences and preserves break history")
        check(AppModel.breakImageSmokeCheck { pictureModel in
            let renderer = ImageRenderer(content: BreakBackgroundView(model: pictureModel).frame(width: 120, height: 80))
            guard let image = renderer.cgImage,
                  let context = CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let data = context.data else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 120, height: 80))
            let pixels = data.bindMemory(to: UInt8.self, capacity: 120 * 80 * 4)
            let center = (40 * 120 + 60) * 4
            return Int(pixels[center]) > 25 && Int(pixels[center]) > Int(pixels[center + 1]) + 25
                && Int(pixels[center]) > Int(pixels[center + 2]) + 25
        }, "picture import persists, renders its pixels, rejects invalid images, and resets safely")
        check(imageBlurSmokeCheck(), "image blur reduces pixel contrast and returns to sharp at zero")
        check(ActivityMonitor.smokeCheck(), "activity metadata matching, disabled state, and unchanged permissions")
        check(AppModel.reminderSmokeCheck(), "overlapping reminders wait until the current overlay ends")
        check(model.countdownSmokeCheck { [self] in
            if model.isShowingHeadsUp {
                return reminderPanel?.isVisible == true && reminderPanel?.canBecomeKey == false && breakWindows.isEmpty
            }
            if model.isPreviewing || model.engine.phase == .resting {
                return reminderPanel?.isVisible != true && breakWindows.count == NSScreen.screens.count
            }
            return reminderPanel?.isVisible != true && breakWindows.isEmpty
        }, "five-second countdown waits for input, preserves focus, and survives pause/preview")
        model.settings.breakTheme = "blur"
        let before = model.engine.remainingSeconds
        model.previewBreak()
        check(model.isPreviewing && breakWindows.count == NSScreen.screens.count, "preview appears on every screen")
        check(breakWindows.allSatisfy { !$0.isOpaque && $0.backgroundColor == .clear }, "desktop blur uses transparent break windows")
        func hasDesktopBlur(_ view: NSView, screenSize: NSSize) -> Bool {
            if let effect = view as? NSVisualEffectView, effect.blendingMode == .behindWindow,
               effect.material == .fullScreenUI, effect.state == .active,
               effect.bounds.width >= screenSize.width, effect.bounds.height >= screenSize.height { return true }
            return view.subviews.contains { hasDesktopBlur($0, screenSize: screenSize) }
        }
        check(breakWindows.allSatisfy { window in
            guard let content = window.contentView else { return false }
            content.layoutSubtreeIfNeeded()
            return hasDesktopBlur(content, screenSize: window.frame.size)
        }, "active native blur covers every break window")
        (breakWindows.first as? BreakWindow)?.cancelOperation(nil)
        check(!model.isPreviewing && breakWindows.isEmpty && model.records.isEmpty, "preview dismisses without history")
        check(model.engine.remainingSeconds == before, "preview preserves timer")
        model.startBreak()
        check(model.engine.phase == .resting && !breakWindows.isEmpty, "real break creates windows")
        let firstEscape = Date()
        model.handleEscape(now: firstEscape)
        check(model.escapeArmed && model.engine.phase == .resting, "first Escape arms without skipping")
        model.handleEscape(isRepeat: true, now: firstEscape.addingTimeInterval(0.1))
        check(model.engine.phase == .resting, "held Escape cannot skip")
        model.handleEscape(now: firstEscape.addingTimeInterval(3))
        check(model.escapeArmed && model.engine.phase == .resting, "expired Escape requires another press")
        model.handleEscape(now: firstEscape.addingTimeInterval(3.2))
        check(model.engine.phase == .focusing && breakWindows.isEmpty && !model.escapeArmed, "second distinct Escape skips and clears confirmation")
        model.startBreak()
        model.pause(minutes: nil)
        check(model.engine.phase == .paused && breakWindows.isEmpty, "pause hides break windows")
        menuNeedsUpdate(statusMenu)
        check(statusMenu.items.first { $0.action == #selector(togglePause) }?.title == "Resume",
              "paused reminders show Resume in the status menu")
        model.resume()
        check(model.engine.phase == .resting && !breakWindows.isEmpty, "resume restores break windows")
        model.setSleeping(true)
        check(model.engine.phase == .paused && breakWindows.isEmpty, "sleep hides break windows")
        model.setDisplaySleeping(true)
        model.setSleeping(false)
        check(model.engine.phase == .paused && breakWindows.isEmpty, "system wake waits for sleeping display")
        model.setDisplaySleeping(false)
        check(model.engine.phase == .resting && !breakWindows.isEmpty, "wake restores break windows")
        model.setLocked(true)
        check(model.engine.phase == .paused && breakWindows.isEmpty, "lock hides break windows")
        model.setLocked(false)
        check(model.engine.phase == .resting && !breakWindows.isEmpty, "unlock restores break windows")
        model.snooze(minutes: 5)
        check(model.engine.phase == .focusing && breakWindows.isEmpty, "snooze closes break windows")
        check(model.completedToday == 0, "snooze never counts a completed break")
        model.startBreak(kind: .long)
        model.skipBreak()
        check(breakWindows.isEmpty && model.engine.phase == .focusing, "skip closes long break windows")
        model.pause(minutes: nil)
        let pausedRemaining = model.engine.remainingSeconds
        model.snooze(minutes: 5)
        model.activeApplicationChanged()
        check(model.engine.phase == .paused && model.engine.remainingSeconds == pausedRemaining + 300, "snooze extends a paused focus timer without resuming")
        model.resume()
        let beforeReminder = model.engine.remainingSeconds
        model.previewReminder(.blink)
        check(reminderPanel?.isVisible == true, "reminder appears during focus")
        check(model.reminderKind == .blink && model.engine.remainingSeconds == beforeReminder, "blink preview preserves focus timer")
        model.previewReminder(.posture)
        check(model.reminderKind == .posture && model.engine.remainingSeconds == beforeReminder, "posture preview preserves focus timer")
        if let activeID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            model.settings.excludedBundleIDs = [activeID]
            check(model.engine.phase == .paused && model.reminderText == nil && reminderPanel?.isVisible == false, "foreground exclusion pauses and dismisses reminder")
            model.settings.excludedBundleIDs = []
            check(model.engine.phase == .focusing, "removing foreground exclusion resumes timer")
        } else {
            failures.append("foreground application available for exclusion check")
        }
        if failures.isEmpty { print("OpenAway platform smoke test passed (\(NSScreen.screens.count) display(s)).") }
        else { fputs("OpenAway platform smoke test FAILED: \(failures.joined(separator: ", "))\n", stderr) }
        model.stop()
        if failures.isEmpty { NSApp.terminate(nil) } else { exit(1) }
    }
}

private final class DashboardWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, let editor = firstResponder as? NSTextView,
           editor.isFieldEditor,
           !editor.visibleRect.contains(editor.convert(event.locationInWindow, from: nil)) {
            makeFirstResponder(nil)
        }
        super.sendEvent(event)
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class BreakWindow: NSWindow {
    var onEscape: ((Bool) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(event.isARepeat) } else { super.keyDown(with: event) }
    }
    override func cancelOperation(_ sender: Any?) {
        let isRepeat = NSApp.currentEvent.map { $0.type == .keyDown && $0.isARepeat } ?? false
        onEscape?(isRepeat)
    }
}
