import WidgetKit
import SwiftUI

@main
struct BabyTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyTrackDailySummaryWidget()
        CareSessionLiveActivityWidget()
    }
}
