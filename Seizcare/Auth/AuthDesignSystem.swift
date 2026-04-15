
//
//  AuthDesignSystem.swift
//  Seizcare
//
//  Design tokens, colour palette, and gradient helpers for the Auth screens.
//

import SwiftUI

// MARK: - Colour Palette

extension Color {
    // Brand
    static let brandPrimary   = Color(red: 0.40, green: 0.36, blue: 0.98) // indigo-violet
    static let brandSecondary = Color(red: 0.56, green: 0.32, blue: 0.95) // purple
    static let brandAccent    = Color(red: 0.29, green: 0.73, blue: 0.96) // sky blue

    // Surfaces
    static let authBackground  = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let cardSurface     = Color.white.opacity(0.80)
    static let fieldBackground = Color(red: 0.94, green: 0.94, blue: 0.97)

    // Text
    static let authPrimaryText   = Color(red: 0.10, green: 0.10, blue: 0.20)
    static let authSecondaryText = Color(red: 0.48, green: 0.48, blue: 0.58)
    static let errorRed          = Color(red: 0.95, green: 0.28, blue: 0.33)
    static let successGreen      = Color(red: 0.18, green: 0.80, blue: 0.44)
}

// MARK: - Dark-mode adaptive versions

extension Color {
    /// Off-white in light mode; near-black in dark mode.
    static var authAdaptiveBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
                : UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
        })
    }

    static var authAdaptiveCard: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.14, blue: 0.20, alpha: 0.90)
                : UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.80)
        })
    }

    static var authAdaptiveField: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.18, blue: 0.24, alpha: 1)
                : UIColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1)
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
