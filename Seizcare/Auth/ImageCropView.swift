//
//  ImageCropView.swift
//  Seizcare
//
//  A circular crop view with pinch-to-zoom and pan gestures.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Crop State ViewModel

final class ImageCropViewModel: ObservableObject {
    let image: UIImage
    let circleSize: CGFloat = 300

    // Committed state
    @Published var committedOffset: CGSize = .zero
    @Published var committedScale:  CGFloat = 1.0

    // Live gesture deltas (not yet committed)
    @Published var dragDelta:  CGSize  = .zero
    @Published var scaleDelta: CGFloat = 1.0

    init(image: UIImage) {
        self.image = image
    }

    // Total values used for rendering
    var totalOffset: CGSize {
        CGSize(
            width:  committedOffset.width  + dragDelta.width,
            height: committedOffset.height + dragDelta.height
        )
    }
    var totalScale: CGFloat { max(0.5, committedScale * scaleDelta) }

    func endDrag() {
        committedOffset = totalOffset
        dragDelta = .zero
    }

    func endMagnify() {
        committedScale = totalScale
        scaleDelta = 1.0
    }

    // MARK: Crop rendering

    /// Renders the user-visible portion inside the circle into a square UIImage.
    func croppedImage(viewSize: CGSize) -> UIImage? {
        let side = circleSize

        // Size of the SwiftUI scaledToFit image at totalScale=1
        let aspect = image.size.width / image.size.height
        let baseW: CGFloat
        let baseH: CGFloat
        if aspect >= 1 {
            baseW = viewSize.width
            baseH = viewSize.width / aspect
        } else {
            baseH = viewSize.height
            baseW = viewSize.height * aspect
        }

        // With user's scale applied
        let renderedW = baseW * totalScale
        let renderedH = baseH * totalScale

        // Top-left of rendered image in view coords
        let imgX = (viewSize.width  - renderedW) / 2 + totalOffset.width
        let imgY = (viewSize.height - renderedH) / 2 + totalOffset.height

        // Top-left of crop circle in view coords
        let circleX = (viewSize.width  - side) / 2
        let circleY = (viewSize.height - side) / 2

        // Where to draw the image inside the output crop canvas (in output coords)
        let drawX = imgX - circleX
        let drawY = imgY - circleY

        // Scale factors: output canvas pixels → rendered image pixels
        // Output canvas is `side × side` (pt), image is drawn at renderedW × renderedH (pt)
        let drawRect = CGRect(x: drawX, y: drawY, width: renderedW, height: renderedH)

        // Render into a `side × side` canvas, clipped to a circle
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let output = renderer.image { ctx in
            let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side))
            circlePath.addClip()
            image.draw(in: drawRect)
        }
        return output
    }
}

// MARK: - ImageCropView

struct ImageCropView: View {
    let image: UIImage
    let onCrop:   (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var vm: ImageCropViewModel
    @State private var viewSize: CGSize = .zero

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image    = image
        self.onCrop   = onCrop
        self.onCancel = onCancel
        _vm = StateObject(wrappedValue: ImageCropViewModel(image: image))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image + overlay layer
            GeometryReader { geo in
                ZStack {
                    // Draggable / zoomable image
                    Image(uiImage: vm.image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(vm.totalScale)
                        .offset(vm.totalOffset)
                        .gesture(dragGesture)
                        .gesture(magnifyGesture)

                    // Dark dimming with circle cutout
                    DimmingOverlay(circleSize: vm.circleSize)
                        .allowsHitTesting(false)

                    // Circle border
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        .frame(width: vm.circleSize, height: vm.circleSize)
                        .allowsHitTesting(false)

                    // Rule-of-thirds guides
                    CrosshairGuides(size: vm.circleSize)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, s in viewSize = s }
            }

            // Controls overlay
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text("Move and Scale")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance spacer
                    Color.clear.frame(width: 86, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Hint
                Text("Pinch to zoom  ·  Drag to reposition")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.bottom, 16)

                // Use Photo button
                Button(action: {
                    guard let cropped = vm.croppedImage(viewSize: viewSize) else { return }
                    onCrop(cropped)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Use Photo")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.authPrimaryButton, Color.authPrimaryButton.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.authPrimaryButton.opacity(0.45), radius: 14, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in vm.dragDelta = v.translation }
            .onEnded   { _ in vm.endDrag() }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in vm.scaleDelta = v.magnification }
            .onEnded   { _ in vm.endMagnify() }
    }
}

// MARK: - Dimming Overlay (circle cutout)

private struct DimmingOverlay: View {
    let circleSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.black.opacity(0.65)))

                let cx = size.width  / 2 - circleSize / 2
                let cy = size.height / 2 - circleSize / 2
                let hole = Path(ellipseIn: CGRect(x: cx, y: cy,
                                                  width: circleSize, height: circleSize))
                ctx.blendMode = .clear
                ctx.fill(hole, with: .color(.black))
            }
            .compositingGroup()
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Rule-of-Thirds Guides

private struct CrosshairGuides: View {
    let size: CGFloat

    var body: some View {
        let lineColor = Color.white.opacity(0.2)
        ZStack {
            // Horizontal thirds
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(lineColor).frame(width: size, height: 0.5)
                Spacer()
                Rectangle().fill(lineColor).frame(width: size, height: 0.5)
                Spacer()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            // Vertical thirds
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(lineColor).frame(width: 0.5, height: size)
                Spacer()
                Rectangle().fill(lineColor).frame(width: 0.5, height: size)
                Spacer()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}
