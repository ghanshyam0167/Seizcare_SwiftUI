//
//  EditProfileView.swift
//  Seizcare
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var contactNumber: String = ""
    
    @State private var originalName: String = ""
    @State private var originalContactNumber: String = ""
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var newProfileImage: UIImage? = nil
    @State private var existingAvatarUrl: String? = nil
    @State private var isSaving = false
    
    // Photo management states
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var photoRemoved = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                        .padding(12)
                        .background(Color.authCardBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Edit Profile")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 32)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    VStack(spacing: 16) {
                        Button(action: { showingActionSheet = true }) {
                            ZStack(alignment: .bottomTrailing) {
                                if !photoRemoved {
                                    if let image = newProfileImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.authPrimaryButton.opacity(0.2), lineWidth: 4))
                                    } else if let localImage = UserDataModel.shared.getLocalAvatarImage() {
                                        Image(uiImage: localImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.authPrimaryButton.opacity(0.2), lineWidth: 4))
                                    } else if let urlString = existingAvatarUrl, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.authPrimaryButton.opacity(0.2), lineWidth: 4))
                                            default:
                                                fallbackAvatar
                                            }
                                        }
                                        .frame(width: 120, height: 120)
                                    } else {
                                        fallbackAvatar
                                    }
                                } else {
                                    fallbackAvatar
                                }
                                
                                Circle()
                                    .fill(Color.authPrimaryButton)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: -4, y: -4)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .confirmationDialog("Change Profile Photo", isPresented: $showingActionSheet, titleVisibility: .visible) {
                            Button("Take Photo") { showingCamera = true }
                            Button("Choose from Gallery") { showingGallery = true }
                            if newProfileImage != nil || existingAvatarUrl != nil {
                                Button("Remove Photo", role: .destructive) {
                                    withAnimation {
                                        newProfileImage = nil
                                        existingAvatarUrl = nil
                                        photoRemoved = true
                                        selectedItem = nil
                                    }
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        .sheet(isPresented: $showingCamera) {
                            CameraPicker(image: $newProfileImage)
                                .onDisappear {
                                    if newProfileImage != nil {
                                        photoRemoved = false
                                    }
                                }
                        }
                        .photosPicker(isPresented: $showingGallery, selection: $selectedItem, matching: .images)
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    await MainActor.run {
                                        newProfileImage = uiImage
                                        photoRemoved = false
                                    }
                                }
                            }
                        }
                        
                        Text("Change Photo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.authPrimaryButton)
                            
                        if !photoRemoved && (newProfileImage != nil || existingAvatarUrl != nil || UserDataModel.shared.getLocalAvatarImage() != nil) {
                            Button(action: {
                                withAnimation {
                                    newProfileImage = nil
                                    existingAvatarUrl = nil
                                    photoRemoved = true
                                    selectedItem = nil
                                }
                            }) {
                                Text("Remove Photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.errorRed)
                            }
                            .padding(.top, -8)
                        }
                    }
                    
                    // Inputs
                    VStack(spacing: 24) {
                        // Full Name Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Full Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.authSecondaryText)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.authSecondaryText)
                                    .frame(width: 20)
                                
                                TextField("Enter your full name", text: $name)
                                    .autocorrectionDisabled()
                                    .textContentType(.name)
                            }
                            .padding()
                            .background(Color.authFieldBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(name.isEmpty ? Color.clear : Color.authPrimaryButton.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Email Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Email Address")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.authSecondaryText)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.authSecondaryText)
                                    .frame(width: 20)
                                
                                TextField("Enter your email", text: $email)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .textContentType(.emailAddress)
                                    .disabled(true)
                                    .foregroundColor(.authSecondaryText)
                            }
                            .padding()
                            .background(Color.authFieldBackground.opacity(0.6))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.authSecondaryText.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Contact Number Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Contact Number")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.authSecondaryText)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "phone")
                                    .foregroundColor(.authSecondaryText)
                                    .frame(width: 20)
                                
                                TextField("Enter your phone number", text: $contactNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                                    .onChange(of: contactNumber) { _, newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered.count > 10 {
                                            contactNumber = String(filtered.prefix(10))
                                        } else if filtered != newValue {
                                            contactNumber = filtered
                                        }
                                    }
                            }
                            .padding()
                            .background(Color.authFieldBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(contactNumber.isEmpty ? Color.clear : Color.authPrimaryButton.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 20)
                }
            }
            
            // Footer Action
            Button(action: saveChanges) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isFormValid ? Color.authPrimaryButton : Color.authButtonDisabled)
                        .frame(height: 56)
                    
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Changes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!isFormValid || isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
        .onAppear(perform: loadCurrentUserData)
    }
    
    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.authFieldBackground)
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.authSecondaryText.opacity(0.3))
            )
    }
    
    private var hasChanges: Bool {
        name != originalName || contactNumber != originalContactNumber || newProfileImage != nil || photoRemoved
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && 
        contactNumber.count == 10 &&
        hasChanges
    }
    
    private func loadCurrentUserData() {
        if let user = UserDataModel.shared.getCurrentUser() {
            self.name = user.fullName
            self.email = user.email
            self.contactNumber = user.contactNumber
            self.existingAvatarUrl = user.avatarUrl
            
            self.originalName = user.fullName
            self.originalContactNumber = user.contactNumber
        }
    }
    
    private func saveChanges() {
        guard let user = UserDataModel.shared.getCurrentUser() else { return }
        isSaving = true
        
        var updated = user
        updated.fullName = name.trimmingCharacters(in: .whitespaces)
        updated.contactNumber = contactNumber.trimmingCharacters(in: .whitespaces)
        
        // Save text details — avatar_url is now excluded from this call
        UserDataModel.shared.updateCurrentUser(updated)
        
        // Handle photo changes
        Task {
            if photoRemoved {
                UserDataModel.shared.clearLocalAvatarImage()
                do {
                    try await SupabaseService.shared.updateUserAvatar(userId: user.id, url: "")
                    UserDataModel.shared.updateAvatarURL("")
                    print("✅ [EditProfile] Avatar removed from DB")
                } catch {
                    print("❌ [EditProfile] Failed to remove avatar: \(error)")
                }
            } else if let image = newProfileImage, let data = image.jpegData(compressionQuality: 0.7) {
                print("📤 [EditProfile] Starting avatar upload for userId: \(user.id)")
                UserDataModel.shared.saveLocalAvatarImage(image)
                do {
                    let url = try await SupabaseService.shared.uploadAvatar(userId: user.id, imageData: data)
                    print("✅ [EditProfile] Uploaded. URL: \(url)")
                    try await SupabaseService.shared.updateUserAvatar(userId: user.id, url: url)
                    print("✅ [EditProfile] avatar_url saved to DB")
                    UserDataModel.shared.updateAvatarURL(url)
                } catch {
                    print("❌ [EditProfile] Avatar upload/save failed: \(error)")
                }
            }
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

#Preview {
    EditProfileView()
}
