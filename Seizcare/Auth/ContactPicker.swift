//
//  ContactPicker.swift
//  Seizcare
//

import SwiftUI
import ContactsUI
import Combine

struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onSelect: (CNContact) -> Void
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelect(contact)
            // We intentionally do not manually set parent.isPresented = false here.
            // CNContactPickerViewController dismisses automatically upon selection or cancellation.
            // SwiftUI's .sheet will natively sync the $showingContactPicker binding to false
            // when the view controller disappears. Manually forcing it causes a double-dismiss 
            // that propagates up and destroys the Settings page's fullScreenCover.
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Intentionally left blank for the same reason.
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // We only care about contacts with phone numbers
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}
