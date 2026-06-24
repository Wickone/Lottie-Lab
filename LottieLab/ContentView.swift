import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var document = AnimationDocument()
    @State private var showingBundledAnimations = false
    @State private var showingExportSheet = false
    @State private var showingEditSheet = false
    @State private var showingRendererComparison = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var statusMessage = ""
    
    // Animation player state
    @State private var animationView = VersionedLottiePlayerView()
    @State private var hasAnimation = false
    @State private var isPlaying = false
    @State private var currentFrame: Double = 0
    @State private var totalFrames: Double = 100
    @State private var animationSpeed: Double = 1.0
    @State private var progressTimer: Timer?
    
    // Frame mapping for offset animations
    @State private var animationStartFrame: Double = 0
    @State private var animationEndFrame: Double = 100
    
    // Animation properties
    @State private var loopMode: PlayerLoopMode = .loop
    
    private var animationPreviewArea: some View {
        VStack(spacing: 16) {
            if hasAnimation {
                runtimeSelector
                    .padding(.horizontal)
            }

            // Animation Display
            animationDisplayView
                .padding(.horizontal)
            
            // Playback Controls (closer to preview)
            if hasAnimation {
                playbackControls
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Edit Button (moved to bottom)
            if hasAnimation {
                editButton
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
    }
    
    private var animationDisplayView: some View {
        Group {
            if hasAnimation {
                print("🖼️ UI: Rendering LottieView with animation")
                return AnyView(
                    LottieView(animationView: animationView)
                        .frame(maxWidth: .infinity, maxHeight: 440) // Updated to 440px
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onAppear {
                            print("🖼️ UI: LottieView appeared")
                        }
                )
            } else {
                print("🖼️ UI: Rendering empty state")
                return AnyView(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 440) // Updated to 440px
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "play.rectangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Import Lottie Animation")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                
                                if !statusMessage.isEmpty {
                                    Text(statusMessage)
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        )
                )
            }
        }
    }
    
    private var editButton: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Edit")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
    
    private var playbackControls: some View {
        VStack(spacing: 32) {
            progressBarSection
            controlButtons
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    private var progressBarSection: some View {
        VStack(spacing: 12) {
            // Frame info and speed control
            HStack {
                Text("Frame \(Int(currentFrame)) / \(Int(totalFrames))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                Spacer()
                Menu {
                    Button("0.5x") { setSpeed(0.5) }
                    Button("1x") { setSpeed(1.0) }
                    Button("1.5x") { setSpeed(1.5) }
                    Button("2x") { setSpeed(2.0) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(String(format: "%.1fx", animationSpeed))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
                .disabled(!hasAnimation)
            }
            
            // Progress slider
            Slider(value: $currentFrame, in: 0...totalFrames) { editing in
                if !editing {
                    seekToFrame(currentFrame)
                }
            }
            .disabled(!hasAnimation)
            .accentColor(.blue)
            
            // Animation properties
            HStack(spacing: 16) {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Menu {
                    Button(action: { setLoopMode(.playOnce) }) {
                        HStack {
                            Text("Play Once")
                            if loopMode == .playOnce {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { setLoopMode(.loop) }) {
                        HStack {
                            Text("Loop")
                            if loopMode == .loop {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { setLoopMode(.autoReverse) }) {
                        HStack {
                            Text("Back-and-Forth")
                            if loopMode == .autoReverse {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: loopModeIcon(loopMode))
                        Text(loopModeText(loopMode))
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
                .disabled(!hasAnimation)
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Previous Frame
            Button(action: previousFrame) {
                Image(systemName: "backward.frame.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .disabled(!hasAnimation)
            
            // Play/Pause
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 42)) // 1.5x larger than .title (28pt)
                    .foregroundColor(.blue)
            }
            .disabled(!hasAnimation)
            
            // Next Frame
            Button(action: nextFrame) {
                Image(systemName: "forward.frame.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .disabled(!hasAnimation)
        }
        .padding(.horizontal, 20)
    }

    private var runtimeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Lottie Runtime", selection: $document.selectedRuntime) {
                ForEach(LottieRuntimeVersion.allCases) { version in
                    Text(version.shortTitle).tag(version)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: document.selectedRuntime) { _, _ in
                reloadAnimationForSelectedRuntime()
            }

            HStack {
                Text("Format \(document.metadata?.formatVersion ?? "Missing")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Test Renderers") {
                    showingRendererComparison = true
                }
                .buttonStyle(.borderless)
                .disabled(document.selectedRuntime != .v461)
            }

            Text(document.selectedRuntime.comparisonNote)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                animationPreviewArea
                    .background(Color(UIColor.systemGray6))
            }
            .navigationTitle("Lottie Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Samples") {
                        showingBundledAnimations = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        showingExportSheet = true
                    }
                    .disabled(!document.isLoaded)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingBundledAnimations) {
            BundledAnimationsView { url in
                loadAnimation(from: url)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            MainExportView(document: document)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPropertiesSheet(
                document: document,
                animationSpeed: $animationSpeed,
                totalFrames: $totalFrames,
                onDocumentChanged: {
                    try reloadAnimationFromDocument()
                }
            )
        }
        .sheet(isPresented: $showingRendererComparison) {
            if let data = document.renderedData {
                RendererComparisonView(
                    data: data,
                    formatVersion: document.metadata?.formatVersion
                )
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
        }
    }
    
    // MARK: - Animation Loading
    private func loadAnimation(from url: URL) {
        statusMessage = "Loading animation..."

        do {
            try document.load(from: url)
            animationSpeed = document.edits.playbackSpeed
            try configurePlayer(with: document.renderedData)
            statusMessage = ""
        } catch {
            hasAnimation = false
            isPlaying = false
            progressTimer?.invalidate()
            statusMessage = "Failed to load animation: \(error.localizedDescription)"
        }
    }

    private func reloadAnimationFromDocument() throws {
        animationSpeed = document.edits.playbackSpeed
        try configurePlayer(with: document.renderedData, preservingProgress: true)
    }

    private func configurePlayer(with data: Data?, preservingProgress: Bool = false) throws {
        guard let data else {
            throw AnimationDocumentError.invalidRootObject
        }

        let previousProgress = preservingProgress ? animationView.currentProgress : 0
        let wasPlaying = preservingProgress && isPlaying

        animationView.stop()
        progressTimer?.invalidate()
        let frameRange = try animationView.load(
            data: data,
            runtime: document.selectedRuntime
        )
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundColor = .clear

        animationStartFrame = frameRange.start
        animationEndFrame = frameRange.end
        totalFrames = animationEndFrame - animationStartFrame
        currentFrame = preservingProgress ? previousProgress * totalFrames : 0
        hasAnimation = true
        isPlaying = wasPlaying
        animationView.currentProgress = previousProgress

        if wasPlaying {
            animationView.play()
            startProgressTracking()
        }
    }

    private func reloadAnimationForSelectedRuntime() {
        guard document.isLoaded else { return }
        do {
            try configurePlayer(
                with: document.renderedData,
                preservingProgress: true
            )
        } catch {
            alertMessage = "\(document.selectedRuntime.title) could not render this animation: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    // MARK: - Playback Controls
    private func togglePlayback() {
        print("🎮 ContentView: Toggle playback - currently playing: \(isPlaying)")
        guard hasAnimation else { 
            print("❌ ContentView: No animation loaded for playback")
            return 
        }
        
        if isPlaying {
            print("🎮 ContentView: Pausing animation")
            animationView.pause()
            progressTimer?.invalidate()
        } else {
            print("🎮 ContentView: Playing animation")
            animationView.play()
            startProgressTracking()
        }
        isPlaying.toggle()
        print("🎮 ContentView: Playback state now: \(isPlaying)")
    }
    
    private func previousFrame() {
        guard hasAnimation else { return }
        let newUserFrame = max(0, currentFrame - 1)
        currentFrame = newUserFrame
        let animationFrame = userFrameToAnimationFrame(newUserFrame)
        animationView.currentFrame = animationFrame
        print("🎮 Previous: User frame \(Int(newUserFrame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func nextFrame() {
        guard hasAnimation else { return }
        let newUserFrame = min(totalFrames, currentFrame + 1)
        currentFrame = newUserFrame
        let animationFrame = userFrameToAnimationFrame(newUserFrame)
        animationView.currentFrame = animationFrame
        print("🎮 Next: User frame \(Int(newUserFrame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func seekToFrame(_ frame: Double) {
        guard hasAnimation else { return }
        let animationFrame = userFrameToAnimationFrame(frame)
        animationView.currentFrame = animationFrame
        print("🎮 Seek: User frame \(Int(frame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func setSpeed(_ speed: Double) {
        print("⚡ ContentView: Setting speed to \(speed)x")
        animationSpeed = speed
        document.updatePlaybackSpeed(speed)
        if hasAnimation {
            animationView.animationSpeed = speed
            print("⚡ ContentView: Speed applied to animationView")
        } else {
            print("❌ ContentView: No animation loaded to apply speed to")
        }
    }
    
    private func setLoopMode(_ mode: PlayerLoopMode) {
        print("🔄 ContentView: Setting loop mode to \(mode)")
        loopMode = mode
        if hasAnimation {
            animationView.loopMode = mode
            print("🔄 ContentView: Loop mode applied to animationView")
        } else {
            print("❌ ContentView: No animation loaded to apply loop mode to")
        }
    }
    
    private func loopModeText(_ mode: PlayerLoopMode) -> String {
        switch mode {
        case .playOnce:
            return "Once"
        case .loop:
            return "Loop"
        case .autoReverse:
            return "Ping-Pong"
        }
    }
    
    private func loopModeIcon(_ mode: PlayerLoopMode) -> String {
        switch mode {
        case .playOnce:
            return "play"
        case .loop:
            return "arrow.clockwise"
        case .autoReverse:
            return "arrow.left.arrow.right"
        }
    }
    
    private func startProgressTracking() {
        print("📊 ContentView: Starting progress tracking")
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if hasAnimation {
                    let animationFrame = animationView.currentFrame
                    let userFrame = animationFrameToUserFrame(animationFrame)
                    
                    if userFrame != currentFrame {
                        currentFrame = max(0, min(totalFrames, userFrame))

                        if Int(userFrame) % 30 == 0 {
                            print("📊 Progress: Animation frame \(Int(animationFrame)) → User frame \(Int(userFrame))/\(Int(totalFrames))")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Test Helper
    private func loadFirstSampleAnimation() {
        print("🧪 ContentView: Auto-loading first sample animation for testing")
        print("🧪 ContentView: Bundle path: \(Bundle.main.bundlePath)")
        
        // Try to load the first available sample animation
        let sampleAnimations = [
            "note_outline_music_sa_outline_to_fill_28.json",
            "compass_music_sa_outline_to_fill_28 2.json",
            "heart_list_music_sa_outline_to_fill_28.json",
            "horse_toy_outline_music_sa_outline_to_fill_28.json",
            "podcast_books_outline_music_sa_outline_to_fill_28.json",
            "radio_outline_music_sa_outline_to_fill_28.json"
        ]
        
        for animationName in sampleAnimations {
            // Try with exact name first
            if let url = Bundle.main.url(forResource: animationName, withExtension: nil) {
                print("🧪 ContentView: Found sample animation: \(animationName)")
                loadAnimation(from: url)
                return
            }
            
            // Try without extension
            let nameWithoutExtension = animationName.replacingOccurrences(of: ".json", with: "")
            if let url = Bundle.main.url(forResource: nameWithoutExtension, withExtension: "json") {
                print("🧪 ContentView: Found sample animation: \(nameWithoutExtension).json")
                loadAnimation(from: url)
                return
            }
        }
        
        print("🧪 ContentView: No sample animations found in bundle")
    }
    
    // MARK: - Frame Mapping Helper Functions
    private func userFrameToAnimationFrame(_ userFrame: Double) -> Double {
        return animationStartFrame + userFrame
    }
    
    private func animationFrameToUserFrame(_ animationFrame: Double) -> Double {
        return animationFrame - animationStartFrame
    }
}
