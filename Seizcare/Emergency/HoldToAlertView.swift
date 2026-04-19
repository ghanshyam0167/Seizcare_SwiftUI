//
//  HoldToAlertView.swift
//  Seizcare
//

import SwiftUI

struct HoldToAlertView: View {
    let onAlertTriggered: () -> Void
    @Binding var isCompleted: Bool

    @State private var isHolding = false
    @State private var progress: CGFloat = 0.0
    @State private var countdown: Int = 3
    @State private var pulse = false
    @State private var holdTask: Task<Void, Never>? = nil
    @State private var hasTriggeredThisHold = false

    private let holdDuration: TimeInterval = 3.0
    private let tickIntervalNs: UInt64 = 16_666_667 // ~60fps

    var body: some View {
        ZStack(alignment: .leading) {
            // Soft red background
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.85, green: 0.10, blue: 0.10).opacity(0.85))
                .shadow(
                    color: Color(red: 0.85, green: 0.10, blue: 0.10).opacity(isHolding ? 0.6 : 0.3),
                    radius: isHolding ? 15 : 10,
                    x: 0,
                    y: isHolding ? 8 : 5
                )

            // Fill animation based on progress (left-to-right color fill)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.20, blue: 0.20),
                                Color(red: 0.65, green: 0.05, blue: 0.05) // Darker red towards trailing edge
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress))
            }

            // Content
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                
                ZStack {
                    if isHolding && progress < 1.0 {
                        Text("\(countdown)")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .id("countdown-\(countdown)")
                    } else {
                        Text(isCompleted ? "alert_triggered" : "hold_to_send_alert")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .transition(.opacity)
                            .id("standard-text-\(isCompleted)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(.white)
        }
        .frame(height: 64)
        // Slight scale-up and subtle pulse
        .scaleEffect(isHolding ? (pulse ? 1.05 : 1.03) : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
        // Use a "touch-down" gesture that doesn't get cancelled by small finger movement.
        // This avoids long-press cancellation inside a ScrollView and prevents timer crashes.
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding { startHold() }
                }
                .onEnded { _ in
                    cancelHoldIfNotCompleted()
                }
        )
        .onChange(of: isCompleted) { completed in
            if !completed {
                resetState()
            }
        }
        .onDisappear {
            cancelHoldTask()
        }
    }

    private func startHold() {
        guard !isCompleted else { return }
        cancelHoldTask()
        print("[UI] Hold started")
        isHolding = true
        progress = 0.0
        countdown = 3
        pulse = false
        hasTriggeredThisHold = false
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulse = true
        }

        let startedAt = Date()
        holdTask = Task { [tickIntervalNs, holdDuration] in
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                let fraction = min(1.0, max(0.0, elapsed / holdDuration))
                
                await MainActor.run {
                    withAnimation(.linear(duration: 0.02)) {
                        progress = CGFloat(fraction)
                    }
                    
                    // Countdown: 3 → 2 → 1 (never 0 while holding)
                    let remaining = max(0.0, holdDuration - elapsed)
                    let newCountdown = max(1, Int(ceil(remaining)))
                    if newCountdown != countdown {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            countdown = newCountdown
                        }
                    }
                }
                
                if fraction >= 1.0 {
                    await MainActor.run {
                        triggerHoldCompletionIfNeeded()
                    }
                    break
                }
                
                do {
                    try await Task.sleep(nanoseconds: tickIntervalNs)
                } catch {
                    break
                }
            }
        }
    }

    private func cancelHoldIfNotCompleted() {
        // If it reaches 100%, let completeHold handle the clean up to avoid double execution
        guard progress < 1.0, !hasTriggeredThisHold else { return }
        print("[UI] Hold cancelled — releasing before 3 seconds")
        cancelHoldTask()
        
        withAnimation(.spring()) {
            isHolding = false
            pulse = false
            progress = 0.0
            countdown = 3
        }
    }

    private func triggerHoldCompletionIfNeeded() {
        guard !hasTriggeredThisHold else { return }
        hasTriggeredThisHold = true
        completeHold()
    }

    private func completeHold() {
        print("[UI] Hold completed → triggering alert")
        cancelHoldTask()
        
        UINotificationFeedbackGenerator().notificationOccurred(.warning) // Strong feedback
        
        withAnimation(.spring()) {
            isHolding = false
            pulse = false
            progress = 0.0 // Reset progress immediately as requested
            countdown = 3
            isCompleted = true
        }
        
        // Exact same function used previously
        onAlertTriggered()
    }
    
    private func resetState() {
        cancelHoldTask()
        withAnimation(.spring()) {
            isHolding = false
            pulse = false
            progress = 0.0
            countdown = 3
            hasTriggeredThisHold = false
        }
    }

    private func cancelHoldTask() {
        holdTask?.cancel()
        holdTask = nil
    }
}
