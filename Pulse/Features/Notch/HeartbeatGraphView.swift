import SwiftUI

/// A compact heartbeat-style line graph representing recent check results.
///
/// Maps each check's status to a vertical position and draws a smooth
/// curve through the points. The line color matches the current aggregate
/// status. Empty (missing) slots are shown as a flat baseline.
struct HeartbeatGraphView: View {
    var results: [CheckResult]
    var maxPoints: Int = MonitorState.maxRecentResults
    var color: Color = MonitorStatus.operational.color

    /// Graph dimensions.
    private let graphWidth: CGFloat = 80
    private let graphHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            Canvas { context, size in
                let points = buildPoints(in: size)
                guard points.count >= 2 else { return }

                let path = smoothPath(through: points)

                context.stroke(
                    path,
                    with: .color(color),
                    lineWidth: 1.5
                )
            }
            .frame(width: graphWidth, height: graphHeight)

            Text("3h")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Point Generation

    /// Builds an array of CGPoints mapping each slot to a position in the canvas.
    ///
    /// The graph always represents a fixed 3-hour window. Results are placed
    /// according to their timestamp within that window. Slots before the
    /// earliest result are backfilled with the earliest known status.
    private func buildPoints(in size: CGSize) -> [CGPoint] {
        let count = maxPoints
        guard count > 1 else { return [] }

        let stepX = size.width / CGFloat(count - 1)
        let insetTop: CGFloat = 2
        let insetBottom: CGFloat = 2
        let usableHeight = size.height - insetTop - insetBottom

        let windowEnd = Date.now
        let windowStart = windowEnd.addingTimeInterval(-windowDuration)
        let slotDuration = windowDuration / Double(count - 1)

        // The status to use for slots before any data exists.
        let fallbackStatus = results.first?.status ?? .operational

        return (0..<count).map { index in
            let x = CGFloat(index) * stepX
            let slotTime = windowStart.addingTimeInterval(slotDuration * Double(index))

            // Find the last result at or before this slot time.
            let status = results.last(where: { $0.timestamp <= slotTime })?.status ?? fallbackStatus

            let y = insetTop + usableHeight * (1 - yFraction(for: status))
            return CGPoint(x: x, y: y)
        }
    }

    /// The fixed time window the graph represents, in seconds.
    private let windowDuration: TimeInterval = 3 * 60 * 60

    /// Maps a status to a vertical fraction (0 = bottom, 1 = top).
    private func yFraction(for status: MonitorStatus) -> CGFloat {
        switch status {
        case .operational: 0.8
        case .degraded, .maintenance: 0.45
        case .downtime, .unknown: 0.1
        }
    }

    // MARK: - Smooth Path (Catmull-Rom)

    /// Creates a smooth path through the given points using Catmull-Rom
    /// spline interpolation converted to cubic Bézier curves.
    private func smoothPath(through points: [CGPoint]) -> Path {
        Path { path in
            path.move(to: points[0])

            for i in 0..<(points.count - 1) {
                let p0 = points[max(i - 1, 0)]
                let p1 = points[i]
                let p2 = points[min(i + 1, points.count - 1)]
                let p3 = points[min(i + 2, points.count - 1)]

                let tension: CGFloat = 6

                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / tension,
                    y: p1.y + (p2.y - p0.y) / tension
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / tension,
                    y: p2.y - (p3.y - p1.y) / tension
                )

                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }
}
