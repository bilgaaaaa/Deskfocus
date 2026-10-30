import SwiftUI
import UIKit

extension OpenURLAction {
    /// Opens Deskfocus' own page in the Settings app, where iOS keeps its permissions and its language.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Log.app.info("Opening Deskfocus in the Settings app")
        callAsFunction(url)
    }
}
