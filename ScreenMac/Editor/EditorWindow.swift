import AppKit

@MainActor
final class EditorWindow: NSWindow {
    var onCopy: (() -> Void)?
    var onCancel: (() -> Void)?
    var onUndo: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53 && modifiers.isEmpty {
            onCancel?()
            return true
        }
        if event.keyCode == 8 && modifiers == .command {
            onCopy?()
            return true
        }
        if event.keyCode == 6 && modifiers == .command {
            onUndo?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
