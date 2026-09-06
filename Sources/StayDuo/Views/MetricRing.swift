import SwiftUI

struct MetricRing: View {
    let displayPercent: Double
    var healthPercent: Double? = nil
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6

    private var progress: Double {
        max(0, min(1, displayPercent / 100))
    }

    private var health: Double {
        healthPercent ?? displayPercent
    }

    private var color: Color {
        if health > 50 {
            return Color(red: 0.22, green: 0.55, blue: 0.95)
        } else if health > 10 {
            return Color(red: 0.95, green: 0.65, blue: 0.15)
        } else {
            return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: displayPercent)

            Text("\(Int(displayPercent.rounded()))%")
                .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}
