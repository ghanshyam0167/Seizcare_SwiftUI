//
//  AvatarViewModel.swift
//  Seizcare
//
//  A shared ObservableObject that holds the current user's avatar image.
//  All views that display the avatar observe this single source of truth.
//  Priority: Local cached file → Remote Supabase URL → nil (fallback icon).
//

import SwiftUI
import Combine

@MainActor
class AvatarViewModel: ObservableObject {
    static let shared = AvatarViewModel()

    @Published var avatarImage: UIImage? = nil

    private var cancellable: AnyCancellable?

    private init() {
        // Listen for avatar change notifications fired by UserDataModel
        cancellable = NotificationCenter.default
            .publisher(for: UserDataModel.avatarDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    // MARK: - Refresh

    /// Loads the avatar: local file first, then remote URL from the user profile.
    func refresh() async {
        guard let user = UserDataModel.shared.getCurrentUser() else {
            avatarImage = nil
            return
        }

        // 1. Try local user-scoped file first (fastest, no network)
        if let local = UserDataModel.shared.getLocalAvatarImage() {
            avatarImage = local
            return
        }

        // 2. Fall back to remote URL stored in Supabase user profile
        if let urlStr = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           !urlStr.isEmpty {
            // 2a. Try the stored URL first (public bucket case)
            if let url = URL(string: urlStr) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) {
                        // Cache locally for future loads
                        UserDataModel.shared.saveLocalAvatarImage(img)
                        avatarImage = img
                        return
                    }
                } catch {
                    print("⚠️ [AvatarViewModel] URL fetch failed: \(error.localizedDescription)")
                }
            }

            // 2b. Fallback for private buckets / non-image URL responses: authenticated download.
            do {
                let data = try await SupabaseService.shared.downloadAvatar(userId: user.id)
                if let img = UIImage(data: data) {
                    UserDataModel.shared.saveLocalAvatarImage(img)
                    avatarImage = img
                    return
                }
            } catch {
                print("⚠️ [AvatarViewModel] Authenticated avatar download failed: \(error.localizedDescription)")
            }
        }

        // 3. No avatar available
        avatarImage = nil
    }

    /// Call this on logout to clear the displayed avatar.
    func clear() {
        avatarImage = nil
    }
}
