import EventKit
import UIKit

extension EKCalendar {
    /// The calendar's color as macOS offers it; iOS EventKit only has `cgColor`.
    /// Lets the shared task sources read `calendar.color?.hexString` on both platforms.
    var color: UIColor? {
        let cgColor: CGColor? = self.cgColor
        return cgColor.map { UIColor(cgColor: $0) }
    }
}
