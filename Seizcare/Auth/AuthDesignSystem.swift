
//
//  AuthDesignSystem.swift
//  Seizcare
//
//  Design tokens, colour palette, and gradient helpers for the Auth screens.
//

import SwiftUI

// MARK: - Colour Palette (Adaptive for Dark/Light Mode)

extension Color {
    // Brand
    static let authPrimaryButton = Color(red: 0.27, green: 0.51, blue: 0.96)
    static let brandPrimary      = Color.authPrimaryButton
    static let brandSecondary    = Color(red: 0.35, green: 0.60, blue: 0.98)
    static let brandAccent       = Color(red: 0.45, green: 0.70, blue: 0.99)
    static let errorRed          = Color(red: 0.95, green: 0.28, blue: 0.33)
    static let successGreen      = Color(red: 0.18, green: 0.80, blue: 0.44)
    
    // Backgrounds
    static var authBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
                : UIColor(red: 0.961, green: 0.969, blue: 0.984, alpha: 1)
        })
    }
    
    static var authCardBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
                : UIColor.white
        })
    }
    
    // Borders & Fields
    static var authInputBorder: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.20, blue: 0.24, alpha: 1)
                : UIColor(red: 0.90, green: 0.92, blue: 0.94, alpha: 1)
        })
    }
    
    static var authFieldBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
                : UIColor.white
        })
    }

    // Texts
    static var authPrimaryText: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1)
        })
    }
    
    static var authSecondaryText: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.65, green: 0.65, blue: 0.70, alpha: 1)
                : UIColor(red: 0.48, green: 0.53, blue: 0.62, alpha: 1)
        })
    }
    
    // Button States
    static var authButtonDisabled: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.28, blue: 0.45, alpha: 1)
                : UIColor(red: 0.69, green: 0.82, blue: 1.0, alpha: 1)
        })
    }
}

// MARK: - Gradients

struct AuthGradients {
    /// Vertical background gradient
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.93, blue: 1.00),
                Color(red: 0.89, green: 0.93, blue: 1.00),
                Color(red: 0.96, green: 0.96, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Dark mode background gradient
    static var backgroundDark: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.07, blue: 0.13),
                Color(red: 0.10, green: 0.09, blue: 0.18),
                Color(red: 0.08, green: 0.10, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Brand button gradient
    static var primaryButton: LinearGradient {
        LinearGradient(
            colors: [Color.brandPrimary, Color.brandSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Decorative orb gradient (top-left)
    static var orbTopLeft: RadialGradient {
        RadialGradient(
            colors: [Color.brandPrimary.opacity(0.30), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    /// Decorative orb gradient (bottom-right)
    static var orbBottomRight: RadialGradient {
        RadialGradient(
            colors: [Color.brandAccent.opacity(0.22), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }
}

// MARK: - Typography

struct AuthTypography {
    static func displayTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(.authPrimaryText)
    }

    static func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.authSecondaryText)
    }
}

// MARK: - Shadow Style

struct AuthCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color.brandPrimary.opacity(0.08), radius: 24, x: 0, y: 8)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func authCardShadow() -> some View {
        modifier(AuthCardShadow())
    }
}

// MARK: - Shake Animation

struct ShakeEffect: GeometryEffect {
    var offset: CGFloat = 0
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 8 * sin(offset * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Custom Back Button

struct CustomBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.authPrimaryText)
                .frame(width: 44, height: 44)
                .background(Color.authCardBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}
