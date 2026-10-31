import AppKit
import Carbon
import Combine
import CoreGraphics
import ScreenCaptureKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppController?

    private var statusItem: NSStatusItem!
    private var captureMenuItem: NSMenuItem!
    private var selectionWindows: [SelectionWindow] = []
    private var reusableSelectionWindows: [SelectionWindow] = []
    private var frozenFrames: [CGDirectDisplayID: CGImage] = [:]
    private var isDismissingSelection = false
    private var isCapturing = false
    private var userRequestedQuit = false
    private var editorWindows: [NSWindow] = []
    private var closingWindows: [NSWindow] = []
    private var settingsWindow: NSWindow?
    let settings = CaptureSettings()
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var hotKeyID: UInt32 = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ScreenMac")

        let menu = NSMenu()
        captureMenuItem = NSMenuItem(title: "Выделить область (\(settings.shortcut.displayName))", action: #selector(startCapture), keyEquivalent: "")
        captureMenuItem.target = self
        menu.addItem(captureMenuItem)
        let quickCopy = NSMenuItem(title: "Скопировать без аннотаций", action: #selector(startQuickCopy), keyEquivalent: "")
        quickCopy.target = self
        menu.addItem(quickCopy)
        menu.addItem(NSMenuItem.separator())
        let preferences = NSMenuItem(title: "Настройки…", action: #selector(showSettings), keyEquivalent: "")
        preferences.target = self
        menu.addItem(preferences)
        let about = NSMenuItem(title: "О ScreenMac", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Выйти из ScreenMac", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        installHotKeyHandler()
        if !registerHotKey(settings.shortcut) {
            showError("Горячая клавиша \(settings.shortcut.displayName) занята. Выберите другую в настройках ScreenMac.")
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        settings.refreshLaunchAtLoginStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Dismissing the temporary capture overlays must never be interpreted as
        // a request to quit the menu bar app. Explicit Quit remains available.
        isDismissingSelection && !userRequestedQuit ? .terminateCancel : .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func quitApp() {
        userRequestedQuit = true
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        alert.messageText = "ScreenMac \(version)"
        alert.informativeText = "Автор: Anatoliy Zyk\n© 2026 Anatoliy Zyk"
        alert.runModal()
    }

    private func installHotKeyHandler() {
        let eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == fourCharCode("LMrk") else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in AppController.shared?.startCapture() }
            return noErr
        }, 1, [eventType], nil, &hotKeyHandler)
        if status != noErr { showError("Не удалось установить обработчик горячей клавиши.") }
    }

    private func registerHotKey(_ shortcut: CaptureShortcut) -> Bool {
        guard hotKeyHandler != nil else { return false }
        var newKey: EventHotKeyRef?
        let nextID = hotKeyID + 1
        let identifier = EventHotKeyID(signature: fourCharCode("LMrk"), id: nextID)
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(), 0, &newKey)
        guard result == noErr, let newKey else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = newKey
        hotKeyID = nextID
        return true
    }

    func changeShortcut(_ shortcut: CaptureShortcut) -> Bool {
        if shortcut == settings.shortcut { return true }
        guard registerHotKey(shortcut) else { return false }
        settings.save(shortcut: shortcut)
        captureMenuItem.title = "Выделить область (\(shortcut.displayName))"
        return true
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.refreshLaunchAtLoginStatus()
            if settings.launchAtLoginNeedsApproval {
                settings.launchAtLoginMessage = "Разрешите автозапуск ScreenMac в настройках объектов входа macOS."
                SMAppService.openSystemSettingsLoginItems()
            } else if settings.launchAtLogin == enabled {
                settings.launchAtLoginMessage = enabled ? "Автозапуск включён." : "Автозапуск выключен."
            } else {
                settings.launchAtLoginMessage = "Не удалось изменить состояние автозапуска. Проверьте настройки объектов входа macOS."
            }
        } catch {
            settings.refreshLaunchAtLoginStatus()
            settings.launchAtLoginMessage = "Не удалось изменить автозапуск: \(error.localizedDescription)"
        }
    }

    @objc private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = CaptureSettingsView(
            settings: settings,
            onShortcut: { [weak self] shortcut in self?.changeShortcut(shortcut) ?? false },
            onLaunchAtLogin: { [weak self] enabled in self?.setLaunchAtLogin(enabled) },
            onOpenLoginItems: { SMAppService.openSystemSettingsLoginItems() }
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Настройки ScreenMac"
        window.delegate = self
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func startCapture() {
        beginCapture(action: .editor)
    }

    @objc private func startQuickCopy() {
        beginCapture(action: .clipboard)
    }

    private func beginCapture(action: CaptureAction) {
        guard selectionWindows.isEmpty, !isDismissingSelection, !isCapturing else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let pointer = NSEvent.mouseLocation
        let activeScreen = screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main ?? screens[0]
        isCapturing = true
        Task { [weak self] in
            await self?.freezeDisplaysAndPresentSelection(screens: [activeScreen], action: action)
        }
    }

    private func freezeDisplaysAndPresentSelection(screens: [NSScreen], action: CaptureAction) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            var frames: [CGDirectDisplayID: CGImage] = [:]
            for screen in screens {
                guard let displayID = displayID(for: screen),
                      let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                let pixelScale = filter.pointPixelScale > 0 ? CGFloat(filter.pointPixelScale) : screen.backingScaleFactor
                config.width = Int((CGFloat(display.width) * pixelScale).rounded())
                config.height = Int((CGFloat(display.height) * pixelScale).rounded())
                config.showsCursor = false
                frames[displayID] = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            }
            guard !frames.isEmpty else {
                isCapturing = false
                showError("Не удалось получить изображение дисплея.")
                return
            }
            frozenFrames = frames
            presentSelection(screens: screens, action: action)
        } catch {
            isCapturing = false
            if CGPreflightScreenCaptureAccess() {
                showError("Снимок не получен: \(error.localizedDescription)")
            } else {
                showError("macOS пока не дала ScreenMac доступ к экрану. Разрешите его в Системных настройках → Конфиденциальность и безопасность → Запись экрана, затем полностью закройте ScreenMac и запустите снова.\n\n\(error.localizedDescription)")
            }
        }
    }

    private func presentSelection(screens: [NSScreen], action: CaptureAction) {
        let screensWithFrames = screens.filter { screen in
            guard let displayID = displayID(for: screen) else { return false }
            return frozenFrames[displayID] != nil
        }
        guard !screensWithFrames.isEmpty else {
            frozenFrames.removeAll(keepingCapacity: true)
            isCapturing = false
            showError("Не удалось получить изображение дисплея.")
            return
        }
        var availableWindows = reusableSelectionWindows
        reusableSelectionWindows.removeAll(keepingCapacity: true)

        for screen in screensWithFrames {
            let window: SelectionWindow
            if let reusableWindow = availableWindows.popLast() {
                window = reusableWindow
                window.setFrame(screen.frame, display: false)
            } else {
                window = SelectionWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            }
            window.onCancel = { [weak self] in self?.cancelSelection() }
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view: SelectionView
            if let existingView = window.contentView as? SelectionView {
                view = existingView
                view.frame = NSRect(origin: .zero, size: screen.frame.size)
            } else {
                view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
                view.autoresizingMask = [.width, .height]
                window.contentView = view
            }
            view.prepare(
                onCancel: { [weak self] in self?.cancelSelection() },
                backgroundImage: displayID(for: screen).flatMap { frozenFrames[$0] },
                onSelect: { [weak self] localRect in
                guard let self else { return }
                guard let displayID = self.displayID(for: screen),
                      let frozenImage = self.frozenFrames[displayID] else {
                    self.frozenFrames.removeAll(keepingCapacity: true)
                    self.closeSelection()
                    self.isCapturing = false
                    self.showError("Не удалось получить сохранённый кадр дисплея.")
                    return
                }
                self.frozenFrames.removeAll(keepingCapacity: true)
                self.closeSelection()
                self.finishCapture(screen: screen, fullImage: frozenImage, localRect: localRect, action: action)
                }
            )
            window.orderFrontRegardless()
            selectionWindows.append(window)
        }

        // If a monitor was disconnected since the previous capture, keep its
        // former overlay hidden in the pool for a later display configuration.
        reusableSelectionWindows.append(contentsOf: availableWindows)
        NSApp.activate(ignoringOtherApps: true)
        let pointer = NSEvent.mouseLocation
        if let window = selectionWindows.first(where: { $0.frame.contains(pointer) }) ?? selectionWindows.first {
            window.makeKeyAndOrderFront(nil)
            if let view = window.contentView { window.makeFirstResponder(view) }
        }
    }

    private func closeSelection() {
        guard !selectionWindows.isEmpty else { return }
        isDismissingSelection = true
        let windowsToHide = selectionWindows
        selectionWindows.removeAll()
        windowsToHide.forEach {
            $0.orderOut(nil)
            ($0.contentView as? SelectionView)?.releaseBackgroundImage()
        }
        reusableSelectionWindows.append(contentsOf: windowsToHide)

        // Let the current AppKit event unwind before clearing callbacks. Keep
        // the borderless windows alive and reuse them instead of closing and
        // releasing them from inside their own keyboard/mouse event handlers.
        DispatchQueue.main.async {
            for window in windowsToHide {
                window.onCancel = nil
                if let view = window.contentView as? SelectionView {
                    view.onCancel = nil
                    view.onSelect = nil
                }
            }
            self.isDismissingSelection = false
        }
    }

    private func cancelSelection() {
        frozenFrames.removeAll(keepingCapacity: true)
        closeSelection()
        isCapturing = false
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func finishCapture(screen: NSScreen, fullImage: CGImage, localRect: CGRect, action: CaptureAction) {
        defer { isCapturing = false }
        let image = autoreleasepool { () -> CGImage? in
            let scaleX = CGFloat(fullImage.width) / screen.frame.width
            let scaleY = CGFloat(fullImage.height) / screen.frame.height
            let crop = CGRect(
                x: floor(localRect.minX * scaleX),
                y: floor((screen.frame.height - localRect.maxY) * scaleY),
                width: ceil(localRect.width * scaleX),
                height: ceil(localRect.height * scaleY)
            ).intersection(CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)).integral
            guard crop.width > 0, crop.height > 0,
                  let cropped = fullImage.cropping(to: crop) else { return nil }
            return independentCopy(of: cropped)
        }
        guard let image else {
            showError("Не удалось обрезать снимок.")
            return
        }
        switch action {
        case .clipboard:
            if copyToClipboard(image) {
                statusItem.button?.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Снимок скопирован")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ScreenMac")
                }
            } else {
                showError("Не удалось скопировать снимок в буфер обмена.")
            }
        case .editor:
            openEditor(image: image)
        }
    }

    private func independentCopy(of image: CGImage) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let preserved = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        )
        let fallbackInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        let fallback = preserved == nil
            ? CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: fallbackInfo.rawValue)
            : nil
        guard let context = preserved ?? fallback else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private func openEditor(image: CGImage) {
        let model = EditorModel(image: image)
        let size = NSSize(width: min(max(CGFloat(image.width) + 80, 680), 1200), height: min(max(CGFloat(image.height) + 150, 480), 850))
        let window = EditorWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        let editor = EditorView(model: model, onCopied: { [weak window] in window?.close() }, onCancel: { [weak window] in window?.close() })
        window.onCopy = { [weak window, weak model] in
            if model?.copyImage() == true { window?.close() }
        }
        window.onCancel = { [weak window] in window?.close() }
        window.onUndo = { [weak model] in
            guard let model, !model.marks.isEmpty else { return }
            model.marks.removeLast()
        }
        window.title = "ScreenMac — снимок"
        window.delegate = self
        window.contentView = NSHostingView(rootView: editor)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindows.append(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        closingWindows.append(window)
        if window === settingsWindow { settingsWindow = nil }
        editorWindows.removeAll { $0 === window }
        // Retain the window through the close event, then release its image-bearing SwiftUI tree.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            if let editorWindow = window as? EditorWindow {
                editorWindow.contentView = nil
                editorWindow.onCopy = nil
                editorWindow.onCancel = nil
                editorWindow.onUndo = nil
            }
            self.closingWindows.removeAll { $0 === window }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ScreenMac"
        alert.informativeText = message
        alert.runModal()
    }
}
