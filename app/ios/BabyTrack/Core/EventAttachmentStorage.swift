import Foundation
import UIKit

enum EventAttachmentStorage {
    static func loadImage(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let url = directoryURL().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func saveImageData(_ data: Data, eventId: UUID) -> String? {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.84) else {
            return nil
        }

        let fileName = "event_photo_\(eventId.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
        let directory = directoryURL()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try jpegData.write(to: directory.appendingPathComponent(fileName), options: [.atomic])
            return fileName
        } catch {
            return nil
        }
    }

    static func delete(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: directoryURL().appendingPathComponent(fileName))
    }

    private static func directoryURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("event_attachments", isDirectory: true)
    }
}
