import Foundation
import ActivityKit

struct CareSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var startedAt: Date
    }

    var childName: String
    var sessionType: String
    var sessionId: String
}
