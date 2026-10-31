import AppKit
import Carbon
import SwiftUI

func fourCharCode(_ text: String) -> OSType {
    text.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
struct CaptureShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyName: String

    static let standard = CaptureShortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(optionKey | cmdKey), keyName: "2")

    var displayName: String {
        let symbols = [
            (UInt32(controlKey), "⌃"),
            (UInt32(optionKey), "⌥"),
            (UInt32(shiftKey), "⇧"),
            (UInt32(cmdKey), "⌘")
        ]
        return symbols.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + keyName
    }
}

enum CaptureAction {
    case clipboard
    case editor
}
struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: CaptureShortcut
    let onCapture: (CaptureShortcut) -> Bool

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.title = shortcut.displayName
        button.onCapture = onCapture
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onCapture = onCapture
        button.currentShortcut = shortcut
        if !button.isRecording { button.title = shortcut.displayName }
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onCapture: ((CaptureShortcut) -> Bool)?
    var currentShortcut: CaptureShortcut = .standard
    var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        title = "Нажмите клавиши…"
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == 53 {
            isRecording = false
            title = currentShortcut.displayName
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }

        let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first?.value
        let isFunctionKey = scalar.map { (0xF704...0xF717).contains($0) } ?? false
        guard modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 || isFunctionKey else {
            title = "Добавьте ⌘, ⌥ или ⌃"
            return
        }

        let keyName: String
        if let scalar, (0xF704...0xF717).contains(scalar) {
            keyName = "F\(scalar - 0xF704 + 1)"
        } else {
            switch event.keyCode {
            case 49: keyName = "Пробел"
            case 48: keyName = "Tab"
            case 36: keyName = "Return"
            case 123: keyName = "←"
            case 124: keyName = "→"
            case 125: keyName = "↓"
            case 126: keyName = "↑"
            default: keyName = (event.charactersIgnoringModifiers ?? "Клавиша \(event.keyCode)").uppercased()
            }
        }
        let shortcut = CaptureShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyName: keyName)
        if onCapture?(shortcut) == true {
            currentShortcut = shortcut
            title = shortcut.displayName
            isRecording = false
            window?.makeFirstResponder(nil)
        } else {
            title = "Сочетание занято"
        }
    }
}
