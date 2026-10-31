import AppKit

@MainActor
final class SelectionWindow: NSWindow {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        makeKey()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            onCancel?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
@MainActor
final class SelectionView: NSView {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var selection: CGRect?
    private var backgroundImage: NSImage?

    func prepare(onCancel: @escaping () -> Void, backgroundImage: CGImage?, onSelect: @escaping (CGRect) -> Void) {
        self.onCancel = onCancel
        self.onSelect = onSelect
        self.backgroundImage = backgroundImage.map { NSImage(cgImage: $0, size: frame.size) }
        start = nil
        selection = nil
        needsDisplay = true
    }

    func releaseBackgroundImage() {
        backgroundImage = nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundImage?.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        let dimming = NSBezierPath(rect: bounds)
        dimming.windingRule = .evenOdd
        if let selection {
            dimming.append(NSBezierPath(rect: selection))
        }
        NSColor.black.withAlphaComponent(0.45).setFill()
        dimming.fill()
        if let selection {
            NSColor.systemBlue.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 2
            border.stroke()
        }
        let hint = "Перетащите мышь для выделения · Esc — отмена"
        hint.draw(at: CGPoint(x: 24, y: bounds.height - 42), withAttributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold)
        ])
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        start = convert(event.locationInWindow, from: nil)
        selection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let current = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y)).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { start = nil }
        guard let selection, selection.width >= 4, selection.height >= 4 else { return }
        onSelect?(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
}
