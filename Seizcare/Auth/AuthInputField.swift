
//
//  AuthInputField.swift
//  Seizcare
//
//  Reusable card-style input field with focus ring, error state, and show/hide password.
//

import SwiftUI

// MARK: - AuthInputField

struct AuthInputField: View {

    let icon:        String
    let placeholder: String
    @Binding var text: String
    var isSecure:    Bool       = false
    var errorMessage: String?   = nil
    var keyboardType: UIKeyboardType = .default

    @State private var isRevealed    = false
    @FocusState private var isFocused: Bool

    // Subtle border animation
    private var borderColor: Color {
        if let err = errorMessage, !err.isEmpty { return .errorRed }
        return isFocused ? .brandPrimary : Color.brandPrimary.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── Field card ──────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isFocused ? Color.brandPrimary : Color.authSecondaryText)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)

                Group {
                    if isSecure && !isRevealed {
                        SecureField(placeholder, text: $text)
                            .focused($isFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .focused($isFocused)
                            .keyboardType(keyboardType)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.authPrimaryText)

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.authSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.authFieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .animation(.easeInOut(duration: 0.2), value: errorMessage)
            )

            // ── Error label ─────────────────────────────────────────────
            if let err = errorMessage, !err.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.errorRed)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: errorMessage)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AuthInputField(icon: "envelope", placeholder: "Email address", text: .constant("user@example.com"))
        AuthInputField(icon: "lock", placeholder: "Password", text: .constant(""), isSecure: true, errorMessage: "At least 8 characters")
    }
    .padding(24)
    .background(Color.authBackground)
}
