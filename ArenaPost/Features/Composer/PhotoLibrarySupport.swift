import CoreTransferable
import Photos
import UniformTypeIdentifiers

/// A movie from the photo picker, copied into its own work directory.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = try MediaPreparer.makeWorkDirectory()
                .appendingPathComponent(received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

enum PhotoLibraryNames {
    /// The asset's original file name (e.g. `IMG_4821.HEIC`), which becomes
    /// the block title. Needs Photos read access; returns `nil` without it.
    static func originalFilename(for itemIdentifier: String?) async -> String? {
        guard let itemIdentifier else { return nil }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil).firstObject else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: asset)
        let primary = resources.first { $0.type == .photo || $0.type == .video } ?? resources.first
        return primary?.originalFilename
    }
}
