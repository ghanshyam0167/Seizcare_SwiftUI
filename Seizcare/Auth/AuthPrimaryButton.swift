
//
//  AuthPrimaryButton.swift
//  Seizcare
//
//  Gradient primary button + plain text secondary button for Auth screens.
//

import SwiftUI

// MARK: - AuthPrimaryButton

struct AuthPrimaryButton: View {

    let title:     LocalizedStringKey
    let isLoading: Bool
    let isEnabled: Bool
    let action:    () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isLoading, isEnabled else { return }
            action()
        }) {
            ZStack {
                // Background gradient / disabled state
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isEnabled
                            ? AnyShapeStyle(AuthGradients.primaryButton)
                            : AnyShapeStyle(Color.authSecondaryText.opacity(0.25))
                    )
                    .frame(height: 56)
                    .shadow(
                        color: isEnabled ? Color.brandPrimary.opacity(0.38) : .clear,
                        radius: 12, x: 0, y: 6
                    )

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("please_wait")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? .white : .authSecondaryText)
                        .tracking(0.3)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading || !isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - AuthTextButton

struct AuthTextButton: View {

    let title:      String
    let highlight:  String      // portion of title shown in brand colour
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            // Build an attributed-like look using Text concatenation
            let parts = title.components(separatedBy: highlight)
            Group {
                if parts.count >= 2 {
                    Text(parts[0])
                        .foregroundColor(.authSecondaryText)
                    + Text(highlight)
                        .foregroundColor(.brandPrimary)
                        .fontWeight(.semibold)
                    + Text(parts.dropFirst().joined(separator: highlight))
                        .foregroundColor(.authSecondaryText)
                } else {
                    Text(title)
                        .foregroundColor(.authSecondaryText)
                }
            }
            .font(.system(size: 15, weight: .regular, design: .rounded))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AuthPrimaryButton(title: "Login", isLoading: false, isEnabled: true) {}
        AuthPrimaryButton(title: "Login", isLoading: true,  isEnabled: true) {}
        AuthPrimaryButton(title: "Login", isLoading: false, isEnabled: false) {}
        AuthTextButton(title: "Don't have an account? Sign Up", highlight: "Sign Up") {}
    }
    .padding(24)
    .background(Color.authBackground)
}
