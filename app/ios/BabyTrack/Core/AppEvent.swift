import Foundation

enum EventType: String, Codable, CaseIterable, Identifiable {
    case breastfeeding
    case breastfeedingLeft
    case breastfeedingRight
    case bottle
    case pumping
    case diaperChange
    case diaperPee
    case diaperPoop
    case sleep
    case fever
    case symptom
    case medication
    case memory

    var id: String { rawValue }

    static var userFacingCases: [EventType] {
        [.breastfeeding, .bottle, .pumping, .diaperChange, .sleep, .fever, .symptom, .medication, .memory]
    }

    var title: String {
        switch self {
        case .breastfeeding: return L10n.tr("quick_action_breastfeeding")
        case .breastfeedingLeft: return L10n.tr("quick_action_breast_left")
        case .breastfeedingRight: return L10n.tr("quick_action_breast_right")
        case .bottle: return L10n.tr("quick_action_bottle")
        case .pumping: return L10n.tr("quick_action_pumping")
        case .diaperChange: return L10n.tr("quick_action_diaper_change")
        case .diaperPee: return L10n.tr("quick_action_diaper_pee")
        case .diaperPoop: return L10n.tr("quick_action_diaper_poop")
        case .sleep: return L10n.tr("quick_action_sleep")
        case .fever: return L10n.tr("quick_action_fever")
        case .symptom: return L10n.tr("quick_action_symptom")
        case .medication: return L10n.tr("quick_action_medication")
        case .memory: return L10n.tr("quick_action_memory")
        }
    }

    var icon: String {
        switch self {
        case .breastfeeding, .breastfeedingLeft, .breastfeedingRight: return "heart"
        case .bottle: return "drop"
        case .pumping: return "drop.circle"
        case .diaperChange, .diaperPee, .diaperPoop: return "square.fill"
        case .sleep: return "moon.zzz"
        case .fever: return "thermometer"
        case .symptom: return "cross.case"
        case .medication: return "pills"
        case .memory: return "photo"
        }
    }

    var isFeedingRelated: Bool {
        switch self {
        case .breastfeeding, .breastfeedingLeft, .breastfeedingRight, .bottle, .pumping:
            return true
        default:
            return false
        }
    }

    var isDiaperRelated: Bool {
        switch self {
        case .diaperChange, .diaperPee, .diaperPoop:
            return true
        default:
            return false
        }
    }
}

struct AppEvent: Identifiable, Codable {
    let id: UUID
    let childId: String
    let type: EventType
    let timestamp: Date
    var note: String
    var payload: [String: String]
    var visibility: Visibility

    enum Visibility: String, Codable, CaseIterable, Identifiable {
        case family
        case parentsOnly
        case `private`

        var id: String { rawValue }
    }

    init(
        id: UUID = UUID(),
        childId: String = "default-child",
        type: EventType,
        timestamp: Date = Date(),
        note: String = "",
        payload: [String: String] = [:],
        visibility: Visibility = .family
    ) {
        self.id = id
        self.childId = childId
        self.type = type
        self.timestamp = timestamp
        self.note = note
        self.payload = payload
        self.visibility = visibility
    }
}
