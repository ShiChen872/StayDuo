import SwiftUI

struct HostMetricsCard: View {
    var metrics: HostMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本机")
                .font(.subheadline.weight(.semibold))

            if let metrics {
                HStack(alignment: .top, spacing: 10) {
                    metricColumn(
                        title: "CPU",
                        displayPercent: metrics.cpuPercent ?? 0,
                        healthPercent: metrics.cpuHealthPercent,
                        subtitle: metrics.loadSubtitle,
                        waiting: metrics.cpuPercent == nil
                    )
                    metricColumn(
                        title: "内存",
                        displayPercent: metrics.memoryUsedPercent,
                        healthPercent: metrics.memoryHealthPercent,
                        subtitle: metrics.memorySubtitle
                    )
                    metricColumn(
                        title: "磁盘",
                        displayPercent: metrics.diskRemainingPercent,
                        healthPercent: metrics.diskHealthPercent,
                        subtitle: metrics.diskSubtitle
                    )
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("读取本机状态…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricColumn(
        title: String,
        displayPercent: Double,
        healthPercent: Double,
        subtitle: String,
        waiting: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            if waiting {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 6)
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(width: 56, height: 56)
            } else {
                MetricRing(displayPercent: displayPercent, healthPercent: healthPercent)
            }
            Text(title)
                .font(.caption2.weight(.medium))
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
