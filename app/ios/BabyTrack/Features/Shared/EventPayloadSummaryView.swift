import SwiftUI
import UIKit

struct EventPayloadSummaryView: View {
    let event: AppEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = memoryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    )
            }

            if let detailLine, !detailLine.isEmpty {
                Text(detailLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var memoryImage: UIImage? {
        guard event.type == .memory,
              let fileName = event.payload["photo_file"] else {
            return nil
        }
        return EventAttachmentStorage.loadImage(fileName: fileName)
    }

    private var detailLine: String? {
        switch event.type {
        case .bottle:
            let amount = event.payload["amount_display"] ?? event.payload["amount_ml"] ?? ""
            let unit = event.payload["amount_unit"] ?? "ml"
            let sourceRaw = event.payload["bottle_source"] ?? ""
            let source: String
            switch sourceRaw {
            case "breastMilk":
                source = L10n.tr("quick_add_bottle_source_breastmilk")
            case "formula":
                source = L10n.tr("quick_add_bottle_source_formula")
            default:
                source = ""
            }
            if !amount.isEmpty, !source.isEmpty {
                return "\(amount) \(unit.uppercased()) • \(source)"
            }
            if !amount.isEmpty {
                return "\(amount) \(unit.uppercased())"
            }
            return source.isEmpty ? nil : source

        case .diaperChange:
            let contentRaw = event.payload["diaper_content"] ?? ""
            switch contentRaw {
            case "pee":
                return L10n.tr("quick_add_diaper_content_pee")
            case "poop":
                return L10n.tr("quick_add_diaper_content_poop")
            case "both":
                return L10n.tr("quick_add_diaper_content_both")
            default:
                return nil
            }

        case .breastfeeding:
            var segments: [String] = []
            if let sideRaw = event.payload["breast_side"] {
                switch sideRaw {
                case "left":
                    segments.append(L10n.tr("quick_add_breast_side_left"))
                case "right":
                    segments.append(L10n.tr("quick_add_breast_side_right"))
                case "both":
                    segments.append(L10n.tr("quick_add_breast_side_both"))
                default:
                    break
                }
            }
            if let duration = event.payload["duration_min"] {
                segments.append(String(format: L10n.tr("quick_add_duration_value_format"), Int(duration) ?? 0))
            }
            return segments.isEmpty ? nil : segments.joined(separator: " • ")

        case .pumping, .sleep, .breastfeedingLeft, .breastfeedingRight:
            if let duration = event.payload["duration_min"] {
                return String(format: L10n.tr("quick_add_duration_value_format"), Int(duration) ?? 0)
            }
            return nil

        case .medication:
            if let planName = event.payload["medication_plan_name"], !planName.isEmpty {
                return planName
            }
            return nil

        case .fever:
            if let value = event.payload["temperature"], !value.isEmpty {
                let unitRaw = event.payload["temperature_unit"] ?? "celsius"
                let unit = unitRaw == "fahrenheit" ? "°F" : "°C"
                return "\(value) \(unit)"
            }
            return nil

        default:
            return nil
        }
    }
}
