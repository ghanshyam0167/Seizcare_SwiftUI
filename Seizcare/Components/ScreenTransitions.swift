//
//  ScreenTransitions.swift
//  Seizcare
//
//  Centralized screen-transition helpers so full-screen navigation feels consistent.
//

import SwiftUI

enum ScreenNavDirection {
    case forward
    case back
}

extension AnyTransition {
    static func screenSlide(_ direction: ScreenNavDirection) -> AnyTransition {
        switch direction {
        case .forward:
            // New screen comes from right → left, old exits to left.
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .back:
            // Back navigation: new comes from left, old exits to right.
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }
    }
}

