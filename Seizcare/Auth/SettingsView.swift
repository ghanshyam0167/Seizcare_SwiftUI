import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var avatarVM: AvatarViewModel
    @State private var user: User? = UserDataModel.shared.getCurrentUser()
    @State private var showingEmergencyContacts = false
    @State private var showingSensitivity = false
    @State private var showingEditProfile = false
    @State private var showingLanguage = false
    @State private var showingWatchConnection = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLogoutConfirmation = false
    @State private var deletePassword = ""
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String? = nil
    @State private var refreshID = UUID()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                
                Spacer()
                
                Text("settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Spacer()
                
                // Invisible button for centering the title properly
                Circle()
                    .fill(Color.clear)
                    .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 24)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Profile Section
                    Button(action: {
                        showingEditProfile = true
                    }) {
                        SettingsProfileCard(
                            name: user?.fullName.isEmpty == false ? user!.fullName : "User",
                            email: user?.email ?? "No email available",
                            avatarUrl: user?.avatarUrl
                        )
                        .id(refreshID)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Safety Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("safety")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)
                            .padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRowCard(
                                icon: "person.2.fill",
                                title: "emergency_contacts",
                                iconColor: .brandPrimary,
                                showDivider: true
                            ) {
                                showingEmergencyContacts = true
                            }
                            
                            SettingsRowCard(
                                icon: "slider.horizontal.3",
                                title: "sensitivity",
                                iconColor: .brandPrimary,
                                showDivider: false
                            ) {
                                showingSensitivity = true
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.authCardBackground)
                        )
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("preferences")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)
                            .padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRowCard(
                                icon: "globe",
                                title: "language",
                                iconColor: .brandPrimary,
                                showDivider: true
                            ) {
                                showingLanguage = true
                            }
                            
                            SettingsRowCard(
                                icon: "applewatch",
                                title: "connect_watch",
                                iconColor: .brandPrimary,
                                showDivider: false
                            ) {
                                showingWatchConnection = true
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.authCardBackground)
                        )
                    }
                    
                    // Danger Zone / Account Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("account")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)
                            .padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRowCard(
                                icon: "lock.fill",
                                title: "change_password",
                                iconColor: .brandPrimary,
                                showDivider: true
                            ) {
                                vm.isChangePasswordPresented = true
                            }
                            
                            SettingsRowCard(
                                icon: "trash.fill",
                                title: "delete_account",
                                iconColor: .errorRed,
                                showDivider: false
                            ) {
                                showingDeleteConfirmation = true
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.authCardBackground)
                        )
                    }
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // Footer Action
            Button(action: {
                showingLogoutConfirmation = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.authCardBackground)
                        .frame(height: 56)
                    
                    Text("logout")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.errorRed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(avatarVM)
        }
        .navigationDestination(isPresented: $showingEmergencyContacts) {
            AddEmergencyContactsView(vm: vm)
        }
        .navigationDestination(isPresented: $showingSensitivity) {
            SensitivitySetupView(vm: vm)
        }
        .navigationDestination(isPresented: $showingLanguage) {
            LanguageSetupView(vm: vm)
        }
        .navigationDestination(isPresented: $showingWatchConnection) {
            WatchConnectionView(vm: vm)
        }
        .navigationDestination(isPresented: $vm.isChangePasswordPresented) {
            ChangePasswordView(vm: vm)
        }
        .navigationDestination(isPresented: $vm.isSettingsForgotPasswordPresented) {
            InAppForgotPasswordFlow(vm: vm)
        }
        // Deletion loading overlay
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Text("Deleting account...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .onAppear {
            self.user = UserDataModel.shared.getCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDataModel.avatarDidChangeNotification)) { _ in
            self.user = UserDataModel.shared.getCurrentUser()
            self.refreshID = UUID() // Forces the view and card to completely redraw!
        }
        .alert(
            "Log Out",
            isPresented: $showingLogoutConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                vm.logout()
            }
        } message: {
            Text("Are you sure you want to log out of your account?")
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            SecureField("Account Password", text: $deletePassword)
            
            Button("Cancel", role: .cancel) {
                deletePassword = ""
            }
            
            Button("Delete Permanently", role: .destructive) {
                isDeletingAccount = true
                Task {
                    do {
                        // 1. Validate email is available locally
                        guard let email = user?.email, !email.isEmpty else {
                            throw URLError(.userAuthenticationRequired)
                        }
                        
                        // 2. Verify password by attempting to sign in
                        _ = try await SupabaseService.shared.signIn(email: email, password: deletePassword)
                        
                        // 3. Password is correct, proceed with deletion
                        try await SupabaseService.shared.deleteAccount()
                        
                        // 4. Logout and clean up
                        vm.logout()
                    } catch {
                        isDeletingAccount = false
                        // If the error is from sign-in, show a friendly message
                        if error.localizedDescription.contains("Invalid login credentials") {
                            deleteErrorMessage = "Incorrect password. Account deletion failed."
                        } else {
                            deleteErrorMessage = error.localizedDescription
                        }
                        deletePassword = ""
                    }
                }
            }
        } message: {
            Text("This action is permanent and cannot be undone. All your data and seizure records will be purged. Please enter your password to confirm.")
        }
        .alert("Deletion Failed", isPresented: .constant(deleteErrorMessage != nil)) {
            Button("OK") { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .task { await avatarVM.refresh() }
    }
}

struct SettingsProfileCard: View {
    let name: String
    let email: String
    let avatarUrl: String?
    @EnvironmentObject var avatarVM: AvatarViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let img = avatarVM.avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.authPrimaryText)
                
                Text(email)
                    .font(.system(size: 14))
                    .foregroundColor(.authSecondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.authSecondaryText.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.authCardBackground)
        )
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.authPrimaryButton.opacity(0.15))
                .frame(width: 50, height: 50)
            Image(systemName: "person.fill")
                .font(.system(size: 20))
                .foregroundColor(.authPrimaryButton)
        }
    }
}

struct SettingsRowCard: View {
    let icon: String
    let title: String
    let iconColor: Color
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.authPrimaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.authSecondaryText.opacity(0.5))
                }
                .padding(16)
                
                if showDivider {
                    Divider()
                        .padding(.leading, 72)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView(vm: AuthViewModel())
}

// MARK: - In-App Forgot Password Modal Component

struct InAppForgotPasswordFlow: View {
    @ObservedObject var vm: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()
            
            // Re-use standard Auth views silently in the background
            switch vm.activeScreen {
            case .forgotPasswordEmail:
                ForgotPasswordEmailView(vm: vm)
            case .forgotPasswordOTP:
                ForgotPasswordOTPView(vm: vm)
            case .forgotPasswordReset:
                ForgotPasswordResetView(vm: vm)
            default:
                Color.authBackground
            }
        }
        .transition(.screenSlide(vm.screenNavDirection))
        .id(vm.activeScreen)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.activeScreen)
    }
}
