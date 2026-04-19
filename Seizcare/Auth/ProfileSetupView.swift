//
//  ProfileSetupView.swift
//  Seizcare
//

import SwiftUI
import PhotosUI
import AVFoundation

@MainActor
struct ProfileSetupView: View {
    @ObservedObject var vm: AuthViewModel
    
    // Photo management states
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var selectedItem: PhotosPickerItem? = nil
    
    // Camera permission
    @State private var showingCameraPermissionAlert = false
    
    // Crop flow
    @State private var imageToCrop: UIImage? = nil
    @State private var showingCrop = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                CustomBackButton { vm.goBack() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 32)
            
            // Header
            VStack(spacing: 8) {
                Text("Complete Profile")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("Tell us a bit more about yourself to personalize your experience.")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer().frame(height: 48)
            
            // Profile Picture Picker
            VStack(spacing: 16) {
                Button(action: { showingActionSheet = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let image = vm.onboardingProfileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.authPrimaryButton.opacity(0.2), lineWidth: 4))
                        } else {
                            Circle()
                                .fill(Color.authFieldBackground)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.authSecondaryText.opacity(0.3))
                                )
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
                    Button("Take Photo") { requestCameraAndOpen() }
                    Button("Choose from Gallery") { showingGallery = true }
                    Button("Cancel", role: .cancel) {}
                }
                .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Please allow camera access in Settings to take a profile photo.")
                }
                .sheet(isPresented: $showingCamera) {
                    CameraPicker(image: $imageToCrop)
                        .onDisappear {
                            if let captured = imageToCrop {
                                imageToCrop = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    imageToCrop = captured
                                    showingCrop = true
                                }
                            }
                        }
                }
                .photosPicker(isPresented: $showingGallery, selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                imageToCrop = uiImage
                                showingCrop = true
                                selectedItem = nil
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingCrop) {
                    if let image = imageToCrop {
                        ImageCropView(image: image) { cropped in
                            vm.onboardingProfileImage = cropped
                            showingCrop = false
                        } onCancel: {
                            showingCrop = false
                            imageToCrop = nil
                        }
                    }
                }
                
                Text(vm.onboardingProfileImage == nil ? "Add Photo" : "Change Photo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.authPrimaryButton)
            }
            
            Spacer().frame(height: 48)
            
            // Full Name Input
            VStack(alignment: .leading, spacing: 10) {
                Text("Full Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.authSecondaryText)
                    .padding(.leading, 4)
                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.authSecondaryText)
                    
                    TextField("Enter your full name", text: $vm.onboardingFullName)
                        .autocorrectionDisabled()
                        .textContentType(.name)
                }
                .padding()
                .background(Color.authFieldBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(vm.onboardingFullName.isEmpty ? Color.clear : Color.authPrimaryButton.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer Action
            Button(action: {
                vm.saveProfileAndContinue()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(vm.onboardingFullName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.authButtonDisabled : Color.authPrimaryButton)
                        .frame(height: 56)
                    
                    Text("Next")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(vm.onboardingFullName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
    
    // MARK: - Camera Permission
    
    private func requestCameraAndOpen() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Already granted — open immediately
            showingCamera = true
        case .notDetermined:
            // First time — ask the user
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showingCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // Previously denied — send to Settings
            showingCameraPermissionAlert = true
        @unknown default:
            showingCameraPermissionAlert = true
        }
    }
}

#Preview {
    ProfileSetupView(vm: AuthViewModel())
}
