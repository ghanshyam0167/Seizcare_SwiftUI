//
//  CameraPicker.swift
//  Seizcare
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Safe guard: only use .camera if it's actually available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.allowsEditing = false // We handle crop ourselves
            picker.cameraDevice = .front
        } else {
            // Fallback to photo library on simulators
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer original image — we crop ourselves via ImageCropView
            if let original = info[.originalImage] as? UIImage {
                parent.image = original
            } else if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
