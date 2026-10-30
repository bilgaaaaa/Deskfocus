import SwiftUI

/// iPhone version of the Mac's green "On / Off" switch: the system switch, tinted green, so the shared forms read the same.
struct ColorfulSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(.green)
    }
}
