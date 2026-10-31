# ScreenMac 1.10 — source release

I’m sharing the source code for ScreenMac 1.10. ScreenMac is a menu bar app for macOS 14 and later that lets you select a screen region, annotate it, and copy or save it as PNG.

### Features

- Capture a selected region on the display under the pointer.
- Annotate with arrows, rectangles, lines, freehand drawing, and text.
- Copy the result to the clipboard or save as PNG.
- Configure a global shortcut and optional launch at login.

I’m sharing the source code first, not the supplied 1.10 DMG: I couldn’t verify the app inside the disk image, and macOS didn’t trust the app in the accompanying Xcode archive. To offer an installer for everyday use, I need to rebuild and sign the app with an Apple Developer ID certificate, then submit it to Apple for notarization. For now, you can build ScreenMac from source with Xcode 15 or later.
