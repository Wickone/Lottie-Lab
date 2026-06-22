import SwiftUI
import Lottie

/// SwiftUI wrapper around the shared Lottie animation view.
struct LottieView: UIViewRepresentable {
    let animationView: LottieAnimationView

    func makeUIView(context: Context) -> LottieAnimationView {
        animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // The owning view controls playback and animation state directly.
    }
}

