import SwiftUI
import PhotosUI
import UIKit

struct EventEditorSheet: View {
    let event: AppEvent
    var onSave: (AppEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: EventType
    @State private var timestamp: Date
    @State private var note: String
    @State private var visibility: AppEvent.Visibility
    @State private var payloadText: String
    @State private var showPayloadError = false
    @State private var memoryPhotoItem: PhotosPickerItem?
    @State private var memoryPhotoData: Data?
    @State private var memoryPhotoFileName: String?
    @State private var memoryPhotoDidChange = false
    @State private var showMemoryCamera = false
    @State private var memoryPhotoLoadError = false
    @State private var memoryCameraUnavailable = false

    init(event: AppEvent, onSave: @escaping (AppEvent) -> Void) {
        self.event = event
        self.onSave = onSave
        _selectedType = State(initialValue: event.type)
        _timestamp = State(initialValue: event.timestamp)
        _note = State(initialValue: event.note)
        _visibility = State(initialValue: event.visibility)
        if let data = try? JSONSerialization.data(withJSONObject: event.payload, options: [.prettyPrinted]),
           let text = String(data: data, encoding: .utf8) {
            _payloadText = State(initialValue: text)
        } else {
            _payloadText = State(initialValue: "{}")
        }
        let photoFileName = event.payload["photo_file"]
        _memoryPhotoFileName = State(initialValue: photoFileName)
        if let photoFileName,
           let image = EventAttachmentStorage.loadImage(fileName: photoFileName),
           let data = image.jpegData(compressionQuality: 0.84) {
            _memoryPhotoData = State(initialValue: data)
        } else {
            _memoryPhotoData = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("event_editor_section_type")) {
                    Picker(L10n.tr("event_editor_event_label"), selection: $selectedType) {
                        ForEach(EventType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section(L10n.tr("event_editor_section_detail")) {
                    DatePicker(L10n.tr("event_editor_date_time_label"), selection: $timestamp)
                    TextField(L10n.tr("event_editor_note_label"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Picker(L10n.tr("event_editor_visibility_label"), selection: $visibility) {
                        Text(L10n.tr("event_editor_visibility_family")).tag(AppEvent.Visibility.family)
                        Text(L10n.tr("event_editor_visibility_parents_only")).tag(AppEvent.Visibility.parentsOnly)
                        Text(L10n.tr("event_editor_visibility_private")).tag(AppEvent.Visibility.`private`)
                    }
                }

                Section(L10n.tr("event_editor_section_payload")) {
                    TextEditor(text: $payloadText)
                        .frame(minHeight: 120)
                        .font(.system(.caption, design: .monospaced))
                }

                memoryPhotoSection
            }
            .navigationTitle(L10n.tr("event_editor_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: memoryPhotoItem) { _ in
                Task {
                    await loadMemoryPhotoData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) { save() }
                }
            }
            .alert(L10n.tr("event_editor_payload_invalid_json"), isPresented: $showPayloadError) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            }
            .alert(L10n.tr("quick_add_memory_photo_error"), isPresented: $memoryPhotoLoadError) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            }
            .alert(L10n.tr("quick_add_memory_camera_unavailable"), isPresented: $memoryCameraUnavailable) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            }
            .sheet(isPresented: $showMemoryCamera) {
                CameraCapturePicker { data in
                    if let data {
                        memoryPhotoData = data
                        memoryPhotoItem = nil
                        memoryPhotoFileName = nil
                        memoryPhotoDidChange = true
                    }
                    showMemoryCamera = false
                }
            }
        }
    }

    @ViewBuilder
    private var memoryPhotoSection: some View {
        if selectedType == .memory {
            Section(L10n.tr("quick_add_memory_photo_label")) {
                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $memoryPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(L10n.tr("quick_add_memory_photo_pick"), systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                    }

                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showMemoryCamera = true
                        } else {
                            memoryCameraUnavailable = true
                        }
                    } label: {
                        Label(L10n.tr("quick_add_memory_photo_take"), systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                if let data = memoryPhotoData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )

                    Button(role: .destructive) {
                        memoryPhotoItem = nil
                        memoryPhotoData = nil
                        memoryPhotoFileName = nil
                        memoryPhotoDidChange = true
                    } label: {
                        Label(L10n.tr("quick_add_memory_photo_remove"), systemImage: "trash")
                    }
                } else {
                    Text(L10n.tr("quick_add_memory_photo_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        let parsedPayload = parsePayload(payloadText)
        guard let payload = parsedPayload else {
            showPayloadError = true
            return
        }

        var finalPayload = payload
        if selectedType == .memory {
            if memoryPhotoDidChange, let memoryPhotoData {
                if let fileName = EventAttachmentStorage.saveImageData(memoryPhotoData, eventId: event.id) {
                    finalPayload["photo_file"] = fileName
                } else if let memoryPhotoFileName {
                    finalPayload["photo_file"] = memoryPhotoFileName
                } else {
                    finalPayload.removeValue(forKey: "photo_file")
                }
            } else if let memoryPhotoFileName {
                finalPayload["photo_file"] = memoryPhotoFileName
            } else {
                finalPayload.removeValue(forKey: "photo_file")
            }
        } else {
            finalPayload.removeValue(forKey: "photo_file")
        }

        let updated = AppEvent(
            id: event.id,
            childId: event.childId,
            type: selectedType,
            timestamp: timestamp,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            payload: finalPayload,
            visibility: visibility
        )
        onSave(updated)
        dismiss()
    }

    private func parsePayload(_ text: String) -> [String: String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [:]
        }
        guard let data = trimmed.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var result: [String: String] = [:]
        for (k, v) in raw {
            result[k] = String(describing: v)
        }
        return result
    }

    private func loadMemoryPhotoData() async {
        guard let memoryPhotoItem else {
            return
        }
        memoryPhotoLoadError = false
        do {
            memoryPhotoData = try await memoryPhotoItem.loadTransferable(type: Data.self)
            memoryPhotoFileName = nil
            memoryPhotoDidChange = true
            if memoryPhotoData == nil {
                memoryPhotoLoadError = true
            }
        } catch {
            memoryPhotoLoadError = true
        }
    }
}

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
                let minutes = Int(round(Double(duration) ?? 0))
                segments.append(String(format: L10n.tr("quick_add_duration_value_format"), minutes))
            }
            return segments.isEmpty ? nil : segments.joined(separator: " • ")

        case .pumping, .sleep, .breastfeedingLeft, .breastfeedingRight:
            if let duration = event.payload["duration_min"] {
                let minutes = Int(round(Double(duration) ?? 0))
                return String(format: L10n.tr("quick_add_duration_value_format"), minutes)
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
