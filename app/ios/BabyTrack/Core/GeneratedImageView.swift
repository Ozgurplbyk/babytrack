import SwiftUI

struct GeneratedImageView: View {
    let relativePath: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage.loadGenerated(relativePath: relativePath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private extension UIImage {
    static func loadGenerated(relativePath: String) -> UIImage? {
        let ns = relativePath as NSString
        let fileName = ns.lastPathComponent
        let ext = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        let subDir = "Generated/" + ns.deletingLastPathComponent

        guard !baseName.isEmpty,
              let url = Bundle.main.url(forResource: baseName, withExtension: ext.isEmpty ? "png" : ext, subdirectory: subDir) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
