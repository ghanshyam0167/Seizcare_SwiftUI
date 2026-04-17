//
//  ProfileSetupView.swift
//  Seizcare
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @ObservedObject var vm: AuthViewModel
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
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
                PhotosPicker(selection: $selectedItem, matching: .images) {
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
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                vm.onboardingProfileImage = uiImage
                            }
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
                    
                    Text("Continue")
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
}

#Preview {
    ProfileSetupView(vm: AuthViewModel())
}
