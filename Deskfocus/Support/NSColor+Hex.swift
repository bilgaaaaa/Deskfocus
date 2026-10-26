import AppKit

extension NSColor {
    /// "#RRGGBB" in sRGB, used to keep calendar colors in the shared state.
    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        let red = Int((rgb.redComponent * 255).rounded())
        let green = Int((rgb.greenComponent * 255).rounded())
        let blue = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
