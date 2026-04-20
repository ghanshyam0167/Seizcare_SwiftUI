//
//  SupabaseRESTClient.swift
//  Seizcare
//
//  Lightweight REST client for Supabase PostgREST.
//  Used for demo-mode pipelines where we want explicit HTTP semantics.
//

import Foundation

struct SupabaseRESTError: Error, LocalizedError {
    let statusCode: Int
    let responseBody: String

    var errorDescription: String? {
        "Supabase REST error (HTTP \(statusCode)): \(responseBody)"
    }
}

struct SupabaseRESTClient {
    let baseURL: URL
    let anonKey: String
    let accessTokenProvider: () async throws -> String

    init(
        baseURL: URL = SupabaseService.supabaseURL,
        anonKey: String = SupabaseService.anonKey,
        accessTokenProvider: @escaping () async throws -> String = { try await SupabaseService.shared.currentAccessToken() }
    ) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.accessTokenProvider = accessTokenProvider
    }

    func request(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: Data? = nil,
        prefer: String? = nil
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let accessToken = try await accessTokenProvider()

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = jsonBody
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if jsonBody != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let prefer {
            req.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unreadable body"
            throw SupabaseRESTError(statusCode: http.statusCode, responseBody: body)
        }
        return data
    }
}

