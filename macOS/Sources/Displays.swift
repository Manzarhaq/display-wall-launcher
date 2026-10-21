import AppKit
import CoreGraphics

struct DisplayChoice {
    let screen: NSScreen
    var id: UInt32 { (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value }
    var label: String {
        let f = screen.frame
        return "\(screen.localizedName) · \(Int(f.width)) × \(Int(f.height)) pt · x \(Int(f.minX)), y \(Int(f.minY))"
    }
    static var available: [DisplayChoice] { NSScreen.screens.map { DisplayChoice(screen: $0) } }
    static var spanningEnabled: Bool? {
        (UserDefaults(suiteName: "com.apple.spaces")?.object(forKey: "spans-displays") as? NSNumber)?.boolValue
    }
    static func bounds(_ selected: [DisplayChoice]) throws -> NSRect {
        guard (1...2).contains(selected.count) else { throw DisplayError.message("Select one display, or two adjacent displays.") }
        guard selected.allSatisfy({ CGDisplayIsInMirrorSet($0.id) == 0 }) else {
            throw DisplayError.message("Turn off display mirroring in System Settings, then select the independent displays.")
        }
        if selected.count == 2 {
            guard spanningEnabled == true else {
                throw DisplayError.message("Spanning needs ‘Displays have separate Spaces’ turned OFF in System Settings → Desktop & Dock → Mission Control. Log out and back in after changing it. This app never changes that setting. If the setting cannot be read, use single-screen preview.")
            }
        }
        return try DisplayLayout.bounds(selected.map { $0.screen.frame })
    }
}

final class WallWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
