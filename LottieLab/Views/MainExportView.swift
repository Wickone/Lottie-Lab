import SwiftUI
import Lottie
import ImageIO
import UniformTypeIdentifiers

struct MainExportView: View {
    let animationURL: URL?
    let colorChanges: [Color: Color]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = "JSON"
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // GIF Export Settings
    @State private var gifFrameRate: Double = 30
    @State private var gifQuality: Double = 0.8
    @State private var gifSize: CGSize = CGSize(width: 300, height: 300)
    
    // GIF Preview
    @State private var previewAnimationView: LottieAnimationView?
    @State private var showingPreview = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Format Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Format")
                        .font(.headline)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("JSON (Lottie)").tag("JSON")
                        Text("GIF Animation").tag("GIF")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Format-specific settings
                if exportFormat == "GIF" {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("GIF Settings")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Frame Rate: \(Int(gifFrameRate)) fps")
                                .font(.subheadline)
                            Slider(value: $gifFrameRate, in: 10...60, step: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quality: \(Int(gifQuality * 100))%")
                                .font(.subheadline)
                            Slider(value: $gifQuality, in: 0.3...1.0, step: 0.1)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size: \(Int(gifSize.width)) × \(Int(gifSize.height))")
                                .font(.subheadline)
                            HStack {
                                Button("Small (200×200)") {
                                    gifSize = CGSize(width: 200, height: 200)
                                    updatePreview()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("Medium (300×300)") {
                                    gifSize = CGSize(width: 300, height: 300)
                                    updatePreview()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("Large (500×500)") {
                                    gifSize = CGSize(width: 500, height: 500)
                                    updatePreview()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        // GIF Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.subheadline)
                            
                            if let previewView = previewAnimationView {
                                VStack {
                                    LottieView(animationView: previewView)
                                        .frame(width: min(gifSize.width, 200), height: min(gifSize.height, 200))
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .onAppear {
                                            previewView.play()
                                        }
                                    
                                    Text("GIF Preview (\(Int(gifSize.width))×\(Int(gifSize.height)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: min(gifSize.width, 200), height: min(gifSize.height, 200))
                                    .overlay(
                                        Text("Preview not available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Export Progress
                if isExporting {
                    VStack(spacing: 8) {
                        Text("Exporting...")
                            .font(.subheadline)
                        ProgressView(value: exportProgress)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Export Button (styled like Edit button)
                Button(action: exportAnimation) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: exportFormat == "JSON" ? "doc.text" : "photo.on.rectangle")
                        }
                        Text(isExporting ? "Exporting..." : "Export \(exportFormat)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(animationURL == nil || isExporting)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Export Animation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Export Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            setupPreview()
        }
        .onChange(of: animationURL) { _, _ in
            setupPreview()
        }
    }
    
    private func setupPreview() {
        guard let animationURL = animationURL else {
            previewAnimationView = nil
            return
        }
        
        do {
            let data = try Data(contentsOf: animationURL)
            let animation = try LottieAnimation.from(data: data)
            
            let animationView = LottieAnimationView(animation: animation)
            animationView.contentMode = .scaleAspectFit
            animationView.loopMode = .loop
            animationView.backgroundBehavior = .pauseAndRestore
            
            previewAnimationView = animationView
        } catch {
            print("❌ Failed to setup GIF preview: \(error)")
            previewAnimationView = nil
        }
    }
    
    private func updatePreview() {
        // Preview is updated via state binding
        if let previewView = previewAnimationView {
            previewView.stop()
            previewView.play()
        }
    }
    
    private func exportAnimation() {
        guard let animationURL = animationURL else { return }
        
        isExporting = true
        exportProgress = 0
        
        Task {
            do {
                if exportFormat == "JSON" {
                    try await exportAsJSON(from: animationURL)
                } else {
                    try await exportAsGIF(from: animationURL)
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showingAlert = true
                    isExporting = false
                }
            }
        }
    }
    
    private func exportAsJSON(from url: URL) async throws {
        await MainActor.run { exportProgress = 0.2 }
        
        let data = try Data(contentsOf: url)
        
        await MainActor.run { exportProgress = 0.4 }
        
        // Parse the JSON to modify colors
        var jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        await MainActor.run { exportProgress = 0.6 }
        
        // Apply color changes to the JSON
        if !colorChanges.isEmpty {
            jsonObject = applyColorChangesToJSON(jsonObject: jsonObject, colorChanges: colorChanges)
            print("✅ Applied \(colorChanges.count) color changes to JSON export")
        }
        
        await MainActor.run { exportProgress = 0.8 }
        
        // Convert back to compact JSON (preserve original format)
        let exportData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "exported_\(Date().timeIntervalSince1970).json"
        let exportURL = documentsPath.appendingPathComponent(fileName)
        
        try exportData.write(to: exportURL)
        
        await MainActor.run {
            exportProgress = 1.0
            self.exportURL = exportURL
            isExporting = false
            showingShareSheet = true
        }
    }
    
    private func exportAsGIF(from url: URL) async throws {
        await MainActor.run { exportProgress = 0.1 }
        
        // Apply color changes to animation data if any exist
        let originalData = try Data(contentsOf: url)
        var animationData = originalData
        
        if !colorChanges.isEmpty {
            print("🎨 Applying \(colorChanges.count) color changes to GIF export")
            let jsonObject = try JSONSerialization.jsonObject(with: originalData, options: [])
            let modifiedJsonObject = applyColorChangesToJSON(jsonObject: jsonObject, colorChanges: colorChanges)
            animationData = try JSONSerialization.data(withJSONObject: modifiedJsonObject, options: [])
        }
        
        let animation = try LottieAnimation.from(data: animationData)
        
        await MainActor.run { exportProgress = 0.2 }
        
        // Calculate frame count and duration
        let duration = animation.duration
        let frameCount = max(Int(duration * gifFrameRate), 20) // Minimum 20 frames for smoother animation
        
        print("🎬 GIF Export - Duration: \(duration)s, Frame count: \(frameCount), FPS: \(gifFrameRate)")
        
        // Create Documents directory path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "exported_\(Date().timeIntervalSince1970).gif"
        let exportURL = documentsPath.appendingPathComponent(fileName)
        
        // Create GIF
        guard let destination = CGImageDestinationCreateWithURL(exportURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw ExportError.gifCreationFailed
        }
        
        // Set GIF properties
        let delayTime = 1.0 / gifFrameRate
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0,
                kCGImagePropertyGIFDelayTime as String: delayTime
            ]
        ]
        
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        await MainActor.run { exportProgress = 0.3 }
        
        // Store captured images
        var capturedImages: [UIImage] = []
        
        // Create animation view with proper setup for rendering
        let (animationView, window) = await MainActor.run { () -> (LottieAnimationView, UIWindow) in
            let animationView = LottieAnimationView(animation: animation)
            animationView.frame = CGRect(origin: .zero, size: gifSize)
            animationView.contentMode = .scaleAspectFit
            animationView.backgroundColor = UIColor.white
            animationView.loopMode = .playOnce
            animationView.animationSpeed = 0 // Disable automatic animation
            
            // Create a hidden window for proper rendering context
            let window = UIWindow(frame: CGRect(origin: .zero, size: gifSize))
            window.backgroundColor = UIColor.white
            window.isHidden = false
            window.alpha = 0.01 // Nearly invisible but still active
            
            // Add animation view to window
            window.addSubview(animationView)
            animationView.frame = window.bounds
            
            // Force initial layout
            window.layoutIfNeeded()
            animationView.layoutIfNeeded()
            
            return (animationView, window)
        }
        
        defer {
            // Clean up window when done
            Task { @MainActor in
                window.isHidden = true
                window.removeFromSuperview()
            }
        }
        
        print("🎬 Capturing \(frameCount) frames with window-based rendering...")
        
        // Capture frames by playing animation and taking snapshots
        for i in 0..<frameCount {
            let progress = CGFloat(i) / CGFloat(frameCount - 1)
            
            await MainActor.run {
                // Set animation progress
                animationView.currentProgress = progress
                
                // Force complete layout and display update
                window.layoutIfNeeded()
                animationView.layoutIfNeeded()
                animationView.layer.setNeedsDisplay()
                animationView.layer.displayIfNeeded()
                
                // Force the entire window hierarchy to update
                window.layer.setNeedsDisplay()
                window.layer.displayIfNeeded()
            }
            
            // Allow time for the animation to update
            try await Task.sleep(nanoseconds: 33_000_000) // ~30fps delay
            
            let image = await MainActor.run {
                // Create image using view's draw method for better accuracy
                let renderer = UIGraphicsImageRenderer(size: gifSize)
                return renderer.image { context in
                    // Fill with white background
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fill(CGRect(origin: .zero, size: gifSize))
                    
                    // Draw the animation view
                    animationView.drawHierarchy(in: animationView.bounds, afterScreenUpdates: true)
                }
            }
            
            capturedImages.append(image)
            
            // Update progress
            await MainActor.run {
                self.exportProgress = 0.3 + (0.4 * Double(i) / Double(frameCount))
            }
            
            print("📸 Captured frame \(i + 1)/\(frameCount) at progress \(Int(progress * 100))%")
        }
        
        await MainActor.run { exportProgress = 0.7 }
        
        // Add captured images to GIF
        for (index, image) in capturedImages.enumerated() {
            if let cgImage = image.cgImage {
                let frameProperties: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: delayTime
                    ]
                ]
                
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                print("✅ Added frame \(index + 1)/\(capturedImages.count) to GIF")
            } else {
                print("❌ Failed to get CGImage for frame \(index + 1)")
            }
            
            // Update progress
            await MainActor.run {
                self.exportProgress = 0.7 + (0.25 * Double(index) / Double(capturedImages.count))
            }
        }
        
        await MainActor.run { exportProgress = 0.95 }
        
        // Finalize GIF
        if !CGImageDestinationFinalize(destination) {
            throw ExportError.gifFinalizationFailed
        }
        
        print("✅ GIF export completed: \(exportURL.path)")
        print("📊 GIF Stats: \(frameCount) frames, \(gifFrameRate) fps, \(Int(gifSize.width))x\(Int(gifSize.height))")
        
        await MainActor.run {
            exportProgress = 1.0
            self.exportURL = exportURL
            isExporting = false
            showingShareSheet = true
        }
    }
    
    // MARK: - Color Replacement Functions
    
    private func applyColorChangesToJSON(jsonObject: Any, colorChanges: [Color: Color]) -> Any {
        guard var json = jsonObject as? [String: Any] else {
            return jsonObject
        }
        
        print("🎨 Starting JSON color replacement with \(colorChanges.count) changes")
        
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
                            print("🎨 Replaced \(shapeTypeName) color: \(colorToHex(originalColor)) → \(colorToHex(newColor))")
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
}

enum ExportError: LocalizedError {
    case gifCreationFailed
    case gifFinalizationFailed
    
    var errorDescription: String? {
        switch self {
        case .gifCreationFailed:
            return "Failed to create GIF file"
        case .gifFinalizationFailed:
            return "Failed to finalize GIF file"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}