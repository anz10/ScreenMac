import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class CaptureSettings: ObservableObject {
    @Published private(set) var shortcut: CaptureShortcut
    @Published var shortcutError: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published var launchAtLoginMessage: String?

    init() {
        let defaults = UserDefaults.standard
        if let code = defaults.object(forKey: "shortcutKeyCode") as? Int,
           let modifiers = defaults.object(forKey: "shortcutModifiers") as? Int,
           let name = defaults.string(forKey: "shortcutKeyName"),
           !name.isEmpty {
            shortcut = CaptureShortcut(keyCode: UInt32(code), modifiers: UInt32(modifiers), keyName: name)
        } else {
            shortcut = .standard
        }
        refreshLaunchAtLoginStatus()
    }

    func save(shortcut: CaptureShortcut) {
        self.shortcut = shortcut
        let defaults = UserDefaults.standard
        defaults.set(Int(shortcut.keyCode), forKey: "shortcutKeyCode")
        defaults.set(Int(shortcut.modifiers), forKey: "shortcutModifiers")
        defaults.set(shortcut.keyName, forKey: "shortcutKeyName")
    }

    func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
            launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLogin = true
            launchAtLoginNeedsApproval = true
        case .notRegistered, .notFound:
            launchAtLogin = false
            launchAtLoginNeedsApproval = false
        @unknown default:
            launchAtLogin = false
            launchAtLoginNeedsApproval = false
        }
    }
}

struct CaptureSettingsView: View {
    @ObservedObject var settings: CaptureSettings
    let onShortcut: (CaptureShortcut) -> Bool
    let onLaunchAtLogin: (Bool) -> Void
    let onOpenLoginItems: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Снимок экрана")
                .font(.title2.bold())
            HStack(spacing: 16) {
                Text("Горячая клавиша")
                    .frame(width: 135, alignment: .leading)
                ShortcutRecorder(shortcut: settings.shortcut) { shortcut in
                    let saved = onShortcut(shortcut)
                    settings.shortcutError = saved ? nil : "Сочетание занято. Нажмите другое."
                    return saved
                }
                .frame(width: 170, height: 28)
            }
            Text(settings.shortcutError ?? "Нажмите на поле, затем нужное сочетание клавиш. Esc отменяет ввод.")
                .font(.caption)
                .foregroundStyle(settings.shortcutError == nil ? Color.secondary : Color.red)
            Divider()
            Toggle("Запускать при входе в систему", isOn: Binding(
                get: { settings.launchAtLogin },
                set: onLaunchAtLogin
            ))
            if settings.launchAtLoginNeedsApproval {
                Text("macOS просит подтвердить автозапуск ScreenMac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Открыть объекты входа") { onOpenLoginItems() }
            }
            if let message = settings.launchAtLoginMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text("После выделения откроется панель рисования. Нажмите ⌘C, чтобы скопировать готовый снимок.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 430)
    }
}
