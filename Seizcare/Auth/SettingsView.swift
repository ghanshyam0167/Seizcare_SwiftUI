import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: AuthViewModel
    @State private var user: User? = UserDataModel.shared.getCurrentUser()
    @State private var showingEmergencyContacts = false
    @State private var showingSensitivity = false
    @State private var showingEditProfile = false
    @State private var showingLanguage = false
    @State private var showingWatchConnection = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: { 
                    // Add back logic if needed, e.g., vm.goBack() 
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                        .padding(12)
                        .background(Color.authCardBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Settings")
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .fullScreenCover(isPresented: $showingEditProfile) {
                        EditProfileView()
                    }
                    
                    // Safety Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAFETY")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)
                            .padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRowCard(
                                icon: "person.2.fill",
                                title: "Emergency Contacts",
                                iconColor: .brandPrimary,
                                showDivider: true
                            ) {
                                showingEmergencyContacts = true
                            }
                            .fullScreenCover(isPresented: $showingEmergencyContacts) {
                                AddEmergencyContactsView(vm: vm)
                            }
                            
                            SettingsRowCard(
                                icon: "slider.horizontal.3",
                                title: "Sensitivity",
                                iconColor: .brandPrimary,
                                showDivider: false
                            ) {
                                showingSensitivity = true
                            }
                            .fullScreenCover(isPresented: $showingSensitivity) {
                                SensitivitySetupView(vm: vm)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.authCardBackground)
                        )
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREFERENCES")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)
                            .padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRowCard(
                                icon: "globe",
                                title: "Language",
                                iconColor: .brandPrimary,
                                showDivider: true
                            ) {
                                showingLanguage = true
                            }
                            .fullScreenCover(isPresented: $showingLanguage) {
                                LanguageSetupView(vm: vm)
                            }
                            
                            SettingsRowCard(
                                icon: "applewatch",
                                title: "Connect your watch",
                                iconColor: .brandPrimary,
                                showDivider: false
                            ) {
                                showingWatchConnection = true
                            }
                            .fullScreenCover(isPresented: $showingWatchConnection) {
                                WatchConnectionView(vm: vm)
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
                vm.logout()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.authCardBackground)
                        .frame(height: 56)
                    
                    Text("Log Out")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.errorRed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
        .onAppear {
            self.user = UserDataModel.shared.getCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDataModel.avatarDidChangeNotification)) { _ in
            self.user = UserDataModel.shared.getCurrentUser()
        }
    }
}

struct SettingsProfileCard: View {
    let name: String
    let email: String
    let avatarUrl: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let urlStr = avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            fallbackAvatar
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 50, height: 50)
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
                    
                    Text(title)
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
