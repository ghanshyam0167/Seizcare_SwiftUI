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

        let currentAvatarUrl = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRemoteAvatar = (currentAvatarUrl?.isEmpty == false)
        let cachedAvatarUrl = UserDataModel.shared.getCachedAvatarUrl()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let localImage = UserDataModel.shared.getLocalAvatarImage()

        // If the server says "no avatar", clear stale caches only if we previously had a remote avatar.
        if !hasRemoteAvatar {
            if cachedAvatarUrl != nil {
                UserDataModel.shared.clearLocalAvatarImage()
                UserDataModel.shared.clearCachedAvatarUrl()
                avatarImage = nil
            } else {
                // e.g. user just picked a local photo but upload hasn't finished yet
                avatarImage = localImage
            }
            return
        }

        // 1. Use local cached file only if it's known to match the latest avatar URL we saw.
        if let local = localImage,
           cachedAvatarUrl == currentAvatarUrl {
            avatarImage = local
            return
        }

        // 2. Fetch remote avatar and overwrite local cache (handles cross-device updates).
        if let urlStr = currentAvatarUrl, !urlStr.isEmpty {
            // 2a. Try the stored URL first (public bucket case). Force refresh to avoid URLCache surprises.
            if let url = URL(string: urlStr) {
                do {
                    var req = URLRequest(url: url)
                    req.cachePolicy = .reloadIgnoringLocalCacheData
                    let (data, _) = try await URLSession.shared.data(for: req)
                    if let img = UIImage(data: data) {
                        // Cache locally for future loads
                        UserDataModel.shared.saveLocalAvatarImage(img)
                        UserDataModel.shared.setCachedAvatarUrl(urlStr)
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
                    UserDataModel.shared.setCachedAvatarUrl(urlStr)
                    avatarImage = img
                    return
                }
            } catch {
                print("⚠️ [AvatarViewModel] Authenticated avatar download failed: \(error.localizedDescription)")
            }
        }

        // 3. If remote fetch failed, fall back to whatever local cache exists.
        avatarImage = localImage
    }

    /// Call this on logout to clear the displayed avatar.
    func clear() {
        avatarImage = nil
    }
}
