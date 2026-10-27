import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system camera, for photos and videos.
struct CameraPicker: UIViewControllerRepresentable {
    enum Capture {
        case photo(UIImage)
        /// A copy in its own work directory; the camera's temp file is gone
        /// once the picker closes.
        case movie(URL)
    }

    let onFinish: (Capture?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Capture?) -> Void

        init(onFinish: @escaping (Capture?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let movieURL = info[.mediaURL] as? URL,
                let directory = try? MediaPreparer.makeWorkDirectory()
            {
                let copy = directory.appendingPathComponent(movieURL.lastPathComponent)
                if (try? FileManager.default.copyItem(at: movieURL, to: copy)) != nil {
                    onFinish(.movie(copy))
                    return
                }
            }
            if let image = info[.originalImage] as? UIImage {
                onFinish(.photo(image))
                return
            }
            onFinish(nil)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
