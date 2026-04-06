import SwiftUI
import WidgetKit
import ActivityKit

struct CareSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CareSessionAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.title)
                    .font(.headline)
                Text(context.state.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.purple)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.childName)
                            .font(.caption.weight(.semibold))
                        Text(context.state.title)
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                        Text(context.state.subtitle)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                }
            } compactLeading: {
                Image(systemName: "heart.fill")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "heart.fill")
            }
        }
    }
}
