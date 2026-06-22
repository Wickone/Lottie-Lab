import SwiftUI
import UniformTypeIdentifiers
import Lottie

struct ContentView: View {
    @State private var selectedAnimationURL: URL?
    @State private var showingBundledAnimations = false
    @State private var showingExportSheet = false
    @State private var showingEditSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var statusMessage = ""
    
    // Color changes from editor
    @State private var currentColorChanges: [Color: Color] = [:]
    
    // Animation player state
    @State private var animationView: LottieAnimationView = LottieAnimationView()
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
    @State private var loopMode: LottieLoopMode = .loop
    
    private var animationPreviewArea: some View {
        VStack(spacing: 16) {
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
                    .disabled(selectedAnimationURL == nil)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingBundledAnimations) {
            BundledAnimationsView(selectedAnimationURL: $selectedAnimationURL)
        }
        .sheet(isPresented: $showingExportSheet) {
            MainExportView(animationURL: selectedAnimationURL, colorChanges: currentColorChanges)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPropertiesSheet(
                animationURL: $selectedAnimationURL,
                animationView: hasAnimation ? animationView : nil,
                animationSpeed: $animationSpeed,
                totalFrames: $totalFrames,
                onColorsChanged: { colorChanges in
                    print("🎨 ContentView: Received color changes: \(colorChanges.count)")
                    currentColorChanges = colorChanges
                    applyColorChangesToMainAnimation(colorChanges)
                }
            )
            .onAppear {
                print("🔍 ContentView: Opening EditPropertiesSheet with URL: \(selectedAnimationURL?.path ?? "nil")")
            }
        }
        .onChange(of: selectedAnimationURL) { _, newURL in
            print("🔄 ContentView: selectedAnimationURL changed to: \(newURL?.path ?? "nil")")
            loadAnimation(from: newURL)
        }
        .onAppear {
            if let url = selectedAnimationURL {
                loadAnimation(from: url)
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
        }
    }
    
    // MARK: - Animation Loading
    private func loadAnimation(from url: URL?) {
        print("🎬 ContentView: loadAnimation called with URL: \(url?.path ?? "nil")")
        
        DispatchQueue.main.async {
            self.statusMessage = "Loading animation..."
        }
        
        guard let url = url else {
            print("🎬 ContentView: No URL provided, clearing animation")
            DispatchQueue.main.async {
                self.hasAnimation = false
                self.isPlaying = false
                self.progressTimer?.invalidate()
                self.statusMessage = ""
            }
            return
        }
        
        // Check if this is a local file (bundled or in Documents)
        let isBundledResource = url.scheme == nil || url.scheme == "file" && url.path.contains(Bundle.main.bundlePath)
        let isDocumentsFile = url.path.contains(FileManager.documentsDirectory().path)
        let isLocalFile = isBundledResource || isDocumentsFile
        
        print("🎬 ContentView: URL scheme: \(url.scheme ?? "none")")
        print("🎬 ContentView: Is bundled: \(isBundledResource)")
        print("🎬 ContentView: Is documents: \(isDocumentsFile)")
        print("🎬 ContentView: Is local: \(isLocalFile)")
        
        let needsSecurityAccess = !isLocalFile
        var hasAccess = true
        
        if needsSecurityAccess {
            print("🎬 ContentView: Attempting to access security scoped resource")
            hasAccess = url.startAccessingSecurityScopedResource()
        } else {
            print("🎬 ContentView: Local file, no security access needed")
        }
        
        if hasAccess {
            defer { 
                if needsSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                    print("🎬 ContentView: Released security scoped resource")
                }
            }
            
            do {
                DispatchQueue.main.async {
                    self.statusMessage = "Reading animation data..."
                }
                
                print("🎬 ContentView: Reading data from URL")
                let data = try Data(contentsOf: url)
                print("🎬 ContentView: Data size: \(data.count) bytes")
                
                DispatchQueue.main.async {
                    self.statusMessage = "Creating animation..."
                }
                
                print("🎬 ContentView: Creating Lottie animation from data")
                let animation = try LottieAnimation.from(data: data)
                print("🎬 ContentView: Animation created successfully")
                print("🎬 ContentView: Start frame: \(animation.startFrame)")
                print("🎬 ContentView: End frame: \(animation.endFrame)")
                print("🎬 ContentView: Total frames: \(animation.endFrame - animation.startFrame)")
                print("🎬 ContentView: Duration: \(animation.duration) seconds")
                print("🎬 ContentView: Frame rate: \(animation.framerate) fps")
                
                // Analyze JSON structure
                analyzeJSONStructure(data: data)
                
                DispatchQueue.main.async {
                    print("🎬 ContentView: Setting animation on existing view")
                    
                    // Stop current animation
                    self.animationView.stop()
                    self.progressTimer?.invalidate()
                    
                    // Set new animation
                    self.animationView.animation = animation
                    self.animationView.loopMode = self.loopMode
                    self.animationView.animationSpeed = self.animationSpeed
                    
                    // Calculate correct frame range
                    let startFrame = Double(animation.startFrame)
                    let endFrame = Double(animation.endFrame)
                    let frameCount = endFrame - startFrame
                    
                    print("🎬 ContentView: Adjusting frame range - Start: \(startFrame), End: \(endFrame), Count: \(frameCount)")
                    
                    // Store animation's actual frame range
                    self.animationStartFrame = startFrame
                    self.animationEndFrame = endFrame
                    
                    // Display 0 to frameCount for user
                    self.totalFrames = frameCount  // Use frame count instead of end frame
                    self.currentFrame = 0  // Always start at 0 for user display
                    self.hasAnimation = true
                    
                    // Don't auto-play, just prepare the animation
                    self.isPlaying = false
                    self.animationView.stop()
                    
                    // Set animation to start frame (maps user frame 0 to animation's actual start)
                    let initialAnimationFrame = self.userFrameToAnimationFrame(0)
                    self.animationView.currentFrame = AnimationFrameTime(initialAnimationFrame)
                    
                    // Clear status message
                    self.statusMessage = ""
                    
                    print("🎬 ContentView: Animation setup complete - User frame 0 → Animation frame \(Int(initialAnimationFrame))")
                }
            } catch {
                print("❌ ContentView: Error loading animation: \(error)")
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to load animation: \(error.localizedDescription)"
                }
            }
        } else {
            print("❌ ContentView: Failed to access security scoped resource")
            DispatchQueue.main.async {
                self.statusMessage = "Failed to access external animation file"
            }
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
        animationView.currentFrame = AnimationFrameTime(animationFrame)
        print("🎮 Previous: User frame \(Int(newUserFrame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func nextFrame() {
        guard hasAnimation else { return }
        let newUserFrame = min(totalFrames, currentFrame + 1)
        currentFrame = newUserFrame
        let animationFrame = userFrameToAnimationFrame(newUserFrame)
        animationView.currentFrame = AnimationFrameTime(animationFrame)
        print("🎮 Next: User frame \(Int(newUserFrame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func seekToFrame(_ frame: Double) {
        guard hasAnimation else { return }
        let animationFrame = userFrameToAnimationFrame(frame)
        animationView.currentFrame = AnimationFrameTime(animationFrame)
        print("🎮 Seek: User frame \(Int(frame)) → Animation frame \(Int(animationFrame))")
    }
    
    private func setSpeed(_ speed: Double) {
        print("⚡ ContentView: Setting speed to \(speed)x")
        animationSpeed = speed
        if hasAnimation {
            animationView.animationSpeed = speed
            print("⚡ ContentView: Speed applied to animationView")
        } else {
            print("❌ ContentView: No animation loaded to apply speed to")
        }
    }
    
    private func setLoopMode(_ mode: LottieLoopMode) {
        print("🔄 ContentView: Setting loop mode to \(mode)")
        loopMode = mode
        if hasAnimation {
            animationView.loopMode = mode
            print("🔄 ContentView: Loop mode applied to animationView")
        } else {
            print("❌ ContentView: No animation loaded to apply loop mode to")
        }
    }
    
    private func loopModeText(_ mode: LottieLoopMode) -> String {
        switch mode {
        case .playOnce:
            return "Once"
        case .loop:
            return "Loop"
        case .autoReverse:
            return "Ping-Pong"
        default:
            return "Loop"
        }
    }
    
    private func loopModeIcon(_ mode: LottieLoopMode) -> String {
        switch mode {
        case .playOnce:
            return "play"
        case .loop:
            return "arrow.clockwise"
        case .autoReverse:
            return "arrow.left.arrow.right"
        default:
            return "arrow.clockwise"
        }
    }
    
    private func startProgressTracking() {
        print("📊 ContentView: Starting progress tracking")
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if hasAnimation {
                let animationFrame = Double(animationView.currentFrame)
                let userFrame = animationFrameToUserFrame(animationFrame)
                
                if userFrame != currentFrame {
                    currentFrame = max(0, min(totalFrames, userFrame))  // Clamp to valid range
                    
                    // Print progress every 30 frames to avoid spam
                    if Int(userFrame) % 30 == 0 {
                        print("📊 Progress: Animation frame \(Int(animationFrame)) → User frame \(Int(userFrame))/\(Int(totalFrames))")
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
                selectedAnimationURL = url
                return
            }
            
            // Try without extension
            let nameWithoutExtension = animationName.replacingOccurrences(of: ".json", with: "")
            if let url = Bundle.main.url(forResource: nameWithoutExtension, withExtension: "json") {
                print("🧪 ContentView: Found sample animation: \(nameWithoutExtension).json")
                selectedAnimationURL = url
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
    
    // MARK: - Color Changes
    private func applyColorChangesToMainAnimation(_ colorChanges: [Color: Color]) {
        print("🎨 ContentView: Applying \(colorChanges.count) color changes to main animation")
        
        guard hasAnimation else {
            print("❌ ContentView: No animation available for color changes")
            return
        }
        
        // Instead of applying generic color changes, reload the animation with modified JSON
        reloadAnimationWithColorChanges(colorChanges)
    }
    
    private func reloadAnimationWithColorChanges(_ colorChanges: [Color: Color]) {
        guard let url = selectedAnimationURL else {
            print("❌ ContentView: No animation URL for reloading")
            return
        }
        
        print("🔄 ContentView: Reloading animation with color changes")
        
        let isBundledResource = url.scheme == nil || url.scheme == "file" && url.path.contains(Bundle.main.bundlePath)
        let isDocumentsFile = url.path.contains(FileManager.documentsDirectory().path)
        let isLocalFile = isBundledResource || isDocumentsFile
        let needsSecurityAccess = !isLocalFile
        
        var hasAccess = true
        if needsSecurityAccess {
            hasAccess = url.startAccessingSecurityScopedResource()
        }
        
        if hasAccess {
            defer {
                if needsSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Read original animation data
                let originalData = try Data(contentsOf: url)
                
                // Apply color changes to JSON if any exist
                var modifiedData = originalData
                if !colorChanges.isEmpty {
                    modifiedData = try applyColorChangesToJSON(data: originalData, colorChanges: colorChanges)
                }
                
                // Create new animation with modified data
                let animation = try LottieAnimation.from(data: modifiedData)
                
                DispatchQueue.main.async {
                    // Preserve current playback state
                    let wasPlaying = self.isPlaying
                    let currentProgress = self.animationView.currentProgress
                    
                    // Update animation
                    self.animationView.animation = animation
                    self.animationView.currentProgress = currentProgress
                    
                    // Restore playback state
                    if wasPlaying {
                        self.animationView.play()
                    }
                    
                    print("✅ ContentView: Animation reloaded with color changes")
                }
            } catch {
                print("❌ ContentView: Error reloading animation with colors: \(error)")
            }
        }
    }
    
    private func applyColorChangesToJSON(data: Data, colorChanges: [Color: Color]) throws -> Data {
        // Parse JSON
        var jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        // Apply color changes using the same logic as export
        jsonObject = applyColorChangesToJSONObject(jsonObject: jsonObject, colorChanges: colorChanges)
        
        // Convert back to data
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    }
    
    private func applyColorChangesToJSONObject(jsonObject: Any, colorChanges: [Color: Color]) -> Any {
        guard var json = jsonObject as? [String: Any] else {
            return jsonObject
        }
        
        // Process layers
        if var layers = json["layers"] as? [[String: Any]] {
            for i in 0..<layers.count {
                layers[i] = processLayerForColors(layer: layers[i], colorChanges: colorChanges)
            }
            json["layers"] = layers
        }
        
        return json
    }
    
    private func processLayerForColors(layer: [String: Any], colorChanges: [Color: Color]) -> [String: Any] {
        var updatedLayer = layer
        
        // Process shapes array
        if var shapes = layer["shapes"] as? [[String: Any]] {
            for i in 0..<shapes.count {
                shapes[i] = processShapeForColors(shape: shapes[i], colorChanges: colorChanges)
            }
            updatedLayer["shapes"] = shapes
        }
        
        return updatedLayer
    }
    
    private func processShapeForColors(shape: [String: Any], colorChanges: [Color: Color]) -> [String: Any] {
        var updatedShape = shape
        
        // Check if this is a fill or stroke shape
        if let shapeType = shape["ty"] as? String {
            if shapeType == "fl" || shapeType == "st" {
                if var colorDict = shape["c"] as? [String: Any],
                   let colorArray = colorDict["k"] as? [Double] {
                    
                    // Find matching color from changes
                    for (originalColor, newColor) in colorChanges {
                        if colorsMatch(colorArray: colorArray, swiftUIColor: originalColor) {
                            let newColorArray = swiftUIColorToColorArray(newColor)
                            colorDict["k"] = newColorArray
                            updatedShape["c"] = colorDict
                            
                            let shapeTypeName = shapeType == "fl" ? "fill" : "stroke"
                            print("🎨 ContentView: Replaced \(shapeTypeName) color: \(colorToHex(originalColor)) → \(colorToHex(newColor))")
                            break
                        }
                    }
                }
            }
        }
        
        // Process nested shapes (for groups)
        if var nestedShapes = shape["it"] as? [[String: Any]] {
            for i in 0..<nestedShapes.count {
                nestedShapes[i] = processShapeForColors(shape: nestedShapes[i], colorChanges: colorChanges)
            }
            updatedShape["it"] = nestedShapes
        }
        
        return updatedShape
    }
    
    private func colorsMatch(colorArray: [Double], swiftUIColor: Color) -> Bool {
        guard colorArray.count >= 3 else { return false }
        
        let uiColor = UIColor(swiftUIColor)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return false
        }
        
        let tolerance: Double = 0.001
        
        return abs(colorArray[0] - Double(components[0])) < tolerance &&
               abs(colorArray[1] - Double(components[1])) < tolerance &&
               abs(colorArray[2] - Double(components[2])) < tolerance &&
               abs((colorArray.count > 3 ? colorArray[3] : 1.0) - (components.count > 3 ? Double(components[3]) : 1.0)) < tolerance
    }
    
    private func swiftUIColorToColorArray(_ color: Color) -> [Double] {
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return [0.0, 0.0, 0.0, 1.0]
        }
        
        return [
            Double(components[0]), // Red
            Double(components[1]), // Green  
            Double(components[2]), // Blue
            components.count > 3 ? Double(components[3]) : 1.0 // Alpha
        ]
    }
    
    private func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    
    // MARK: - JSON Analysis
    private func analyzeJSONStructure(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📊 JSON Analysis:")
                
                // Check basic properties
                if let ip = json["ip"] { print("📊 In Point: \(ip)") }
                if let op = json["op"] { print("📊 Out Point: \(op)") }
                if let fr = json["fr"] { print("📊 Frame Rate: \(fr)") }
                if let w = json["w"] { print("📊 Width: \(w)") }
                if let h = json["h"] { print("📊 Height: \(h)") }
                
                // Check layers structure
                if let layers = json["layers"] as? [[String: Any]] {
                    print("📊 Number of layers: \(layers.count)")
                    
                    for (index, layer) in layers.enumerated() {
                        if let ip = layer["ip"], let op = layer["op"] {
                            print("📊 Layer \(index): in=\(ip), out=\(op)")
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to analyze JSON: \(error)")
        }
    }
    
}
