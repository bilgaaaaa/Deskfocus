import UIKit

extension UIColor {
    /// "#RRGGBB" in sRGB, used to keep calendar colors in the shared state; the iPhone twin of `NSColor.hexString`.
    var hexString: String? {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil),
              let components = converted.components,
              components.count >= 3 else { return nil }
        let channels = components.prefix(3).map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}
