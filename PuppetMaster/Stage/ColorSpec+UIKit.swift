import UIKit

extension ColorSpec {
    /// Bridge from the pure-Swift character/backdrop data into something drawable.
    /// This conversion is the only place `Core`'s colours meet a UI framework.
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
