import SwiftUI

/// Draws a soft glow behind the notch by filling a rounded rectangle
/// with the glow color and blurring it. The shape is positioned so
/// its top half extends above the panel (clipped by the window bounds),
/// leaving only the bottom glow visible around the notch edges.
struct NotchGlowView: View {
    var glowColor: Color
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    private let blurRadius: CGFloat = 12
    private let cornerRadius: CGFloat = 12

    @State private var isPulsing = false

    var body: some View {
        let extraTop: CGFloat = 32
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(glowColor)
            .frame(width: notchWidth + 8, height: notchHeight + extraTop)
            .offset(y: -extraTop / 2)
            .padding(blurRadius)
            .blur(radius: blurRadius)
            .padding(-blurRadius)
            .opacity(isPulsing ? 1 : 0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
