import AppKit
import Combine
import CoreGraphics
import CoreText

enum MarkTool: String, CaseIterable, Identifiable {
    case arrow = "Стрелка"
    case rectangle = "Рамка"
    case line = "Линия"
    case pencil = "Карандаш"
    case text = "Текст"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .line: "line.diagonal"
        case .pencil: "pencil.tip"
        case .text: "textformat"
        }
    }
}

enum Mark {
    case arrow(CGPoint, CGPoint, NSColor, CGFloat)
    case rectangle(CGPoint, CGPoint, NSColor, CGFloat)
    case line(CGPoint, CGPoint, NSColor, CGFloat)
    case pencil([CGPoint], NSColor, CGFloat)
    case text(CGPoint, String, NSColor, CGFloat)
}

@MainActor
final class EditorModel: ObservableObject {
    let image: CGImage
    @Published var tool: MarkTool = .arrow
    @Published var color: NSColor = .systemRed
    @Published var strokeWidth: CGFloat = 5
    @Published var textSize: CGFloat = 24
    @Published var marks: [Mark] = []
    @Published var message: String?

    init(image: CGImage) { self.image = image }

    func copyImage() -> Bool {
        guard let png = renderedPNGData() else {
            message = "Не удалось подготовить изображение."
            return false
        }
        guard writePNGToClipboard(png) else {
            message = "Не удалось скопировать изображение."
            return false
        }
        return true
    }

    func renderedPNGData() -> Data? {
        autoreleasepool {
            guard let rendered = renderedImage() else { return nil }
            return encodePNG(rendered)
        }
    }

    func renderedImage() -> CGImage? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        drawContent(in: context)
        return context.makeImage()
    }

    func drawContent(in context: CGContext) {
        let canvas = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: canvas)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for mark in marks {
            switch mark {
            case let .arrow(start, end, color, width):
                context.setLineWidth(width)
                context.setStrokeColor(color.cgColor)
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
                let angle = atan2(end.y - start.y, end.x - start.x)
                let head = min(36, max(12, width * 4))
                context.move(to: end)
                context.addLine(to: CGPoint(x: end.x - head * cos(angle - .pi / 6), y: end.y - head * sin(angle - .pi / 6)))
                context.move(to: end)
                context.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6), y: end.y - head * sin(angle + .pi / 6)))
                context.strokePath()
            case let .rectangle(start, end, color, width):
                context.setLineWidth(width)
                context.setStrokeColor(color.cgColor)
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                context.stroke(rect)
            case let .line(start, end, color, width):
                context.setLineWidth(width)
                context.setStrokeColor(color.cgColor)
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
            case let .pencil(points, color, width):
                guard let first = points.first else { continue }
                context.setLineWidth(width)
                context.setStrokeColor(color.cgColor)
                context.move(to: first)
                for point in points.dropFirst() { context.addLine(to: point) }
                context.strokePath()
            case let .text(point, string, color, size):
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: size, weight: .semibold),
                    .foregroundColor: color
                ]
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
                context.textPosition = point
                CTLineDraw(line, context)
            }
        }
    }
}
