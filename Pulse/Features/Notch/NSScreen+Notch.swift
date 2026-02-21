import AppKit

extension NSScreen {

    /// The Core Graphics display identifier for this screen.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    /// Whether the screen has a camera housing (notch) at the top.
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// The rectangle occupied by the notch in global screen coordinates,
    /// computed as the gap between the auxiliary top-left and top-right areas.
    /// Returns `nil` when there is no notch.
    var notchRect: NSRect? {
        guard hasNotch,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea else {
            return nil
        }
        let x = leftArea.maxX
        let width = rightArea.minX - leftArea.maxX
        let y = frame.maxY - safeAreaInsets.top
        let height = safeAreaInsets.top
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// The built-in screen, which is the one most likely to have a notch.
    static var builtIn: NSScreen? {
        screens.first { $0.displayID == CGMainDisplayID() }
            ?? screens.first { $0.hasNotch }
            ?? main
    }
}
