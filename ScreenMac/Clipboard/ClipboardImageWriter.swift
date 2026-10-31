import AppKit
import CoreGraphics

func encodePNG(_ image: CGImage) -> Data? {
    autoreleasepool {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

func copyToClipboard(_ image: CGImage) -> Bool {
    guard let png = encodePNG(image) else { return false }
    return writePNGToClipboard(png)
}

func writePNGToClipboard(_ png: Data) -> Bool {
    autoreleasepool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        return pasteboard.writeObjects([item])
    }
}
