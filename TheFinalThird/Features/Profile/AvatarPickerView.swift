import PhotosUI
import SwiftUI

/// Lets the user pick a photo from their library and upload it as their
/// profile photo. Crops to a centered square and downscales to 512×512
/// before encoding to JPEG so we never push a 12 MP photo to storage.
///
/// Uses SwiftUI's `PhotosPicker` (PHPicker out-of-process) so we don't
/// require `NSPhotoLibraryUsageDescription` and the user's library is
/// never directly accessed by the app.
struct AvatarPickerView: View {
    let userID: UUID
    /// Called once the upload completes successfully with the new
    /// cache-busted URL.
    let onUpload: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isUploading = false
    @State private var error: String?

    private let repo: ProfileRepository = LiveProfileRepository()

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                TexturePanel(texture: .leather, opacity: 0.08, zoom: 1.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FTColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isUploading ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(previewImage == nil || isUploading)
                    .tint(FTColor.gold)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await load(newItem) }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: FTSpace.xl) {
            // Preview circle with gold ring
            ZStack {
                Circle().fill(FTColor.surface)
                if let img = previewImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(FTColor.inkFaint)
                }
            }
            .frame(width: 220, height: 220)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(FTColor.gold.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: FTColor.goldGlow.opacity(0.5), radius: 24, x: 0, y: 0)

            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(previewImage == nil ? "Choose a photo" : "Choose another")
                        .font(FTType.body(15, weight: .medium))
                }
                .foregroundStyle(FTColor.gold)
                .padding(.horizontal, FTSpace.lg)
                .padding(.vertical, FTSpace.md)
                .background(FTColor.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(FTColor.gold.opacity(0.4), lineWidth: 0.5)
                )
            }

            Text("We'll crop it to a circle and store a 512px copy. Replaceable any time.")
                .font(FTType.caption(11))
                .foregroundStyle(FTColor.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpace.xl)

            if let error {
                Text(error)
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpace.xl)
            }

            Spacer()
        }
        .padding(.top, FTSpace.xxl)
        .padding(.horizontal, FTSpace.xl)
    }

    // MARK: Actions

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else {
                error = "Couldn't read that photo."
                return
            }
            previewImage = AvatarPickerView.squareCropAndResize(uiImage, target: 512)
            error = nil
        } catch {
            self.error = "Couldn't load photo: \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard let img = previewImage,
              let data = img.jpegData(compressionQuality: 0.85)
        else {
            error = "Couldn't encode photo."
            return
        }
        isUploading = true; defer { isUploading = false }
        do {
            let url = try await repo.uploadAvatar(data: data, userID: userID)
            HapticsService.shared.success()
            onUpload(url)
            dismiss()
        } catch {
            self.error = "Upload failed: \(error.localizedDescription)"
        }
    }

    /// Center-crops the image to a square, then renders it at the
    /// target size in points. Keeps orientation correct (some photos
    /// arrive with an EXIF rotation that UIGraphicsImageRenderer
    /// handles automatically).
    static func squareCropAndResize(_ image: UIImage, target: CGFloat) -> UIImage {
        let normalized = image.normalizedOrientation()
        let dim = min(normalized.size.width, normalized.size.height)
        let originX = (normalized.size.width - dim) / 2
        let originY = (normalized.size.height - dim) / 2

        // Crop in image-space pixels via cgImage (which is in pixels).
        let scale = normalized.scale
        guard let cg = normalized.cgImage?.cropping(to: CGRect(
            x: originX * scale,
            y: originY * scale,
            width: dim * scale,
            height: dim * scale
        )) else { return image }
        let cropped = UIImage(cgImage: cg, scale: scale, orientation: .up)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target))
        return renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: target, height: target))
        }
    }
}

private extension UIImage {
    /// Returns an image rendered with `.up` orientation by re-drawing
    /// the bitmap. EXIF-rotated photos otherwise crop incorrectly.
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(at: .zero) }
    }
}
