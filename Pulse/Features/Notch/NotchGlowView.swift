import SwiftUI

/// Draws a soft glow behind the notch by filling a rounded rectangle
/// with the glow color and blurring it. The shape is positioned so
/// its top half extends above the panel (clipped by the window bounds),
/// leaving only the bottom glow visible around the notch edges.
struct NotchGlowView: View {
    var glowColor: Color
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    var isPulseEnabled: Bool = true

    private let blurRadius: CGFloat = 12
    private let cornerRadius: CGFloat = 12

    /// Drives the breathing opacity. Toggled by an async loop so the
    /// animation can be cleanly cancelled when pulsing is disabled.
    @State private var isBright = true
    @State private var pulseTask: Task<Void, Never>?

    var body: some View {
        let extraTop: CGFloat = 32
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(glowColor)
            .frame(width: notchWidth + 8, height: notchHeight + extraTop)
            .offset(y: -extraTop / 2)
            .padding(blurRadius)
            .blur(radius: blurRadius)
            .padding(-blurRadius)
            .opacity(isBright ? 1 : 0.4)
            .animation(.easeInOut(duration: 1.5), value: isBright)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: isPulseEnabled, initial: true) {
                pulseTask?.cancel()
                if isPulseEnabled {
                    pulseTask = Task {
                        while !Task.isCancelled {
                            isBright.toggle()
                            try? await Task.sleep(for: .seconds(1.5))
                        }
                    }
                } else {
                    isBright = true
                }
            }
    }
}
