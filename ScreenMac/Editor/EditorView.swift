import AppKit
import Combine
import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel
    let onCopied: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(MarkTool.allCases) { tool in
                    Button { model.tool = tool } label: {
                        Image(systemName: tool.symbol)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.tool == tool ? .accentColor : nil)
                    .help(tool.rawValue)
                    .accessibilityLabel(tool.rawValue)
                }
                ColorPicker("Цвет", selection: Binding(
                    get: { Color(nsColor: model.color) },
                    set: { model.color = NSColor($0) }
                ))
                .labelsHidden()
                .frame(width: 36)
                Button("Отменить", systemImage: "arrow.uturn.backward") {
                    if !model.marks.isEmpty { model.marks.removeLast() }
                }
                .disabled(model.marks.isEmpty)
                Spacer(minLength: 8)
                Button("Закрыть", systemImage: "xmark", action: onCancel)
                    .help("Отменить снимок (Esc)")
                Button("Копировать", systemImage: "doc.on.doc", action: copyImage)
                    .keyboardShortcut("c", modifiers: .command)
                Button("Сохранить PNG", systemImage: "square.and.arrow.down", action: saveImage)
            }
            .padding(12)
            HStack(spacing: 10) {
                Text(model.tool == .text ? "Размер текста" : "Толщина")
                    .frame(width: 100, alignment: .leading)
                Slider(
                    value: model.tool == .text
                        ? $model.textSize
                        : $model.strokeWidth,
                    in: model.tool == .text ? 12...48 : 1...20,
                    step: 1
                )
                .frame(width: 180)
                Text(model.tool == .text
                     ? "\(Int(model.textSize)) px"
                     : "\(Int(model.strokeWidth)) px")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            Divider()
            AnnotationCanvas(model: model)
                .background(Color(nsColor: .windowBackgroundColor))
            Text("⌘C — копировать · ⌘Z — отменить пометку · Esc — закрыть снимок. Для текста щёлкните в нужном месте.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .alert("ScreenMac", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func copyImage() {
        if model.copyImage() { onCopied() }
    }

    private func saveImage() {
        guard let png = model.renderedPNGData() else {
            model.message = "Не удалось подготовить PNG."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ScreenMac-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).png"
        if panel.runModal() == .OK, let url = panel.url {
            do { try png.write(to: url, options: .atomic) }
            catch { model.message = "Не удалось сохранить файл: \(error.localizedDescription)" }
        }
    }
}

struct AnnotationCanvas: NSViewRepresentable {
    @ObservedObject var model: EditorModel

    func makeNSView(context: Context) -> CanvasView { CanvasView(model: model) }
    func updateNSView(_ view: CanvasView, context: Context) { view.needsDisplay = true }
}

@MainActor
final class CanvasView: NSView {
    let model: EditorModel
    private var start: CGPoint?
    private var end: CGPoint?
    private var strokePoints: [CGPoint] = []
    private var subscription: AnyCancellable?

    init(model: EditorModel) {
        self.model = model
        super.init(frame: .zero)
        subscription = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private var imageRect: CGRect {
        let ratio = min(bounds.width / CGFloat(model.image.width), bounds.height / CGFloat(model.image.height))
        let size = CGSize(width: CGFloat(model.image.width) * ratio, height: CGFloat(model.image.height) * ratio)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }

    private func imagePoint(_ event: NSEvent) -> CGPoint? {
        let point = convert(event.locationInWindow, from: nil)
        let rect = imageRect
        guard rect.contains(point) else { return nil }
        return CGPoint(x: (point.x - rect.minX) * CGFloat(model.image.width) / rect.width,
                       y: (point.y - rect.minY) * CGFloat(model.image.height) / rect.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = imageRect
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / CGFloat(model.image.width), y: rect.height / CGFloat(model.image.height))
        model.drawContent(in: context)
        if let start, let end {
            context.setStrokeColor(model.color.cgColor)
            context.setLineWidth(3)
            switch model.tool {
            case .arrow:
                context.setLineWidth(model.strokeWidth)
                context.move(to: start); context.addLine(to: end); context.strokePath()
            case .rectangle:
                context.setLineWidth(model.strokeWidth)
                context.stroke(CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y)))
            case .line:
                context.setLineWidth(model.strokeWidth)
                context.move(to: start); context.addLine(to: end); context.strokePath()
            case .pencil:
                context.setLineWidth(model.strokeWidth)
                if let first = strokePoints.first {
                    context.move(to: first)
                    for point in strokePoints.dropFirst() { context.addLine(to: point) }
                    context.strokePath()
                }
            case .text: break
            }
        }
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        guard let point = imagePoint(event) else { return }
        if model.tool == .text {
            let alert = NSAlert()
            alert.messageText = "Текст аннотации"
            alert.addButton(withTitle: "Добавить")
            alert.addButton(withTitle: "Отмена")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            alert.accessoryView = field
            if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
                model.marks.append(.text(point, field.stringValue, model.color, model.textSize))
            }
        } else {
            start = point
            end = point
            strokePoints = [point]
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard start != nil, let point = imagePoint(event) else { return }
        end = point
        if model.tool == .pencil { strokePoints.append(point) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { start = nil; end = nil; strokePoints = []; needsDisplay = true }
        guard let start, let end else { return }
        if model.tool == .pencil {
            if strokePoints.count > 1 { model.marks.append(.pencil(strokePoints, model.color, model.strokeWidth)) }
            return
        }
        guard hypot(end.x - start.x, end.y - start.y) >= 3 else { return }
        switch model.tool {
        case .arrow: model.marks.append(.arrow(start, end, model.color, model.strokeWidth))
        case .rectangle: model.marks.append(.rectangle(start, end, model.color, model.strokeWidth))
        case .line: model.marks.append(.line(start, end, model.color, model.strokeWidth))
        case .pencil: break
        case .text: break
        }
    }
}
