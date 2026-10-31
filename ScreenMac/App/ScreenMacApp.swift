import AppKit

@MainActor
@main
enum ScreenMacApp {
    static func main() {
        // This utility owns its windows through AppKit and SwiftUI hosting views,
        // so run an AppKit application loop directly instead of an empty SwiftUI scene.
        let application = NSApplication.shared
        let delegate = AppController()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
