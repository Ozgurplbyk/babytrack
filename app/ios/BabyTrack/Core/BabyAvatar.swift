import Foundation
import SwiftUI
import UIKit

enum BabyAvatarCatalog {
    static let generatedPaths: [String] = [
        "quick_add/memory.png",
        "quick_add/sleep.png",
        "quick_add/bottle.png",
        "quick_add/diaper.png",
        "quick_add/pumping.png",
        "quick_add/breast_left.png",
        "quick_add/breast_right.png",
        "quick_add/symptom.png",
        "home/cards/daily_feeding.png",
        "home/cards/daily_sleep.png"
    ]

    static var fallback: String {
        generatedPaths.first ?? "quick_add/memory.png"
    }

    static func defaultPath(for id: UUID) -> String {
        let hash = abs(id.uuidString.hashValue)
        let index = hash % max(generatedPaths.count, 1)
        return generatedPaths[index]
    }
}

enum BabyAvatarStorage {
    static func loadImage(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let url = directoryURL().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func saveImageData(_ rawData: Data, profileId: UUID) -> String? {
        guard let image = UIImage(data: rawData),
              let data = image.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let fileName = "avatar_\(profileId.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
        let directory = directoryURL()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: [.atomic])
            return fileName
        } catch {
            return nil
        }
    }

    static func delete(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        let url = directoryURL().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    private static func directoryURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("baby_avatars", isDirectory: true)
    }
}

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

struct BabyAvatarView: View {
    let profile: BabyProfile
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let fileName = profile.photoFileName,
               let image = BabyAvatarStorage.loadImage(fileName: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                GeneratedImageView(relativePath: profile.avatarAssetPath, contentMode: .fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct BabyProfileQuickSwitcher: View {
    let profiles: [BabyProfile]
    let selectedId: UUID?
    var compact: Bool = false
    var onSelect: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profiles) { profile in
                        profileChip(profile)
                            .id(profile.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                scrollToSelected(proxy: proxy)
            }
            .onChange(of: selectedId) { _ in
                scrollToSelected(proxy: proxy)
            }
        }
    }

    private func profileChip(_ profile: BabyProfile) -> some View {
        let selected = selectedId == profile.id

        return Button {
            onSelect(profile.id)
        } label: {
            HStack(spacing: 8) {
                BabyAvatarView(profile: profile, size: compact ? 30 : 34)

                Text(profile.name)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 8 : 10)
            .background {
                if selected {
                    LinearGradient(
                        colors: [Color.accentColor, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                        .fill(normalFill)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                    .strokeBorder(selected ? Color.white.opacity(0.24) : borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.985, opacity: 0.95))
    }

    private var normalFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color(.secondarySystemBackground)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.68)
    }

    private func scrollToSelected(proxy: ScrollViewProxy) {
        guard let selectedId else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(selectedId, anchor: .center)
            }
        }
    }
}
