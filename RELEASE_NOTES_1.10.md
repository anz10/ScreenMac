# ScreenMac 1.10 — source release

I’m sharing the source code for ScreenMac 1.10. ScreenMac is a menu bar app for macOS 14 and later that lets you select a screen region, annotate it, and copy or save it as PNG.

### Features

- Capture a selected region on the display under the pointer.
- Annotate with arrows, rectangles, lines, freehand drawing, and text.
- Copy the result to the clipboard or save as PNG.
- Configure a global shortcut and optional launch at login.

The supplied 1.10 DMG passed its checksum check, but I couldn’t verify the app inside it. The app in the accompanying Xcode archive also failed macOS Gatekeeper’s trust check, so I’m not offering the DMG as an installer. A ready-to-install build needs a new Developer ID signature and Apple notarization. For now, build ScreenMac from source with Xcode 15 or later.
