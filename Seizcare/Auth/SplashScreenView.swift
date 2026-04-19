//
//  SplashScreenView.swift
//  Seizcare
//

import SwiftUI

struct SplashScreenView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var isActive = false
    @State private var size: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    @State private var didBootstrap = false
    
    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()
            
            if isActive {
                AuthRootView(vm: vm)
            } else {
                VStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                }
                .scaleEffect(size)
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                self.size = 0.9
                self.opacity = 1.0
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            
            // Keep the splash up for at least 1s for a smooth animation,
            // but don't cancel session restore when the view switches.
            async let restore: Void = vm.tryRestoreSession()
            try? await Task.sleep(for: .seconds(1))
            await restore
            
            withAnimation(.easeIn(duration: 0.3)) {
                self.isActive = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
