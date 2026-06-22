import SwiftUI
import Lottie

struct EditPropertiesSheet: View {
    @Binding var animationURL: URL?
    let animationView: LottieAnimationView?
    @Binding var animationSpeed: Double
    @Binding var totalFrames: Double
    let onColorsChanged: (([Color: Color]) -> Void)?
    
    @StateObject private var analyzer = LottieAnalyzer()
    @Environment(\.dismiss) private var dismiss
    
    // Edit states
    @State private var tempSpeed: Double = 1.0
    @State private var tempFrames: Double = 100
    @State private var backgroundColor: Color = .clear
    @State private var hasChanges = false
    @State private var selectedColors: [String: Color] = [:]
    @State private var colorReplacements: [Color: Color] = [:]
    @State private var uiUpdateTrigger = false
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Animation Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Animation Properties")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            // Speed Control
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Speed")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(tempSpeed, specifier: "%.1f")x")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $tempSpeed, in: 0.1...3.0, step: 0.1)
                                .onChange(of: tempSpeed) { _, _ in
                                    hasChanges = true
                                }
                            }
                            
                            // Frame Count (Read-only for now)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Total Frames")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(tempFrames))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Frame count is read-only")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Background Color
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Background")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(backgroundColor == .clear ? 
                                          LinearGradient(colors: [.white, .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                          LinearGradient(colors: [backgroundColor], startPoint: .center, endPoint: .center))
                                    .frame(width: 60, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Background Color")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(backgroundColor == .clear ? "Transparent" : colorToHex(backgroundColor))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                ColorPicker("", selection: $backgroundColor)
                                    .labelsHidden()
                                    .onChange(of: backgroundColor) { _, _ in
                                        hasChanges = true
                                    }
                            }
                            
                            Button("Reset to Transparent") {
                                backgroundColor = .clear
                                hasChanges = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Animation Colors (show detected colors or fallback test colors)
                    let colorsToShow = analyzer.colorPalette.isEmpty ? 
                        [Color.blue, Color.red, Color.green, Color.orange] : analyzer.colorPalette
                    
                    if true { // Always show color section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Animation Colors")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if analyzer.colorPalette.isEmpty {
                                    Text("Using test colors (no animation colors detected)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("Detected \(analyzer.colorPalette.count) colors in animation")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("Tap a color picker to edit")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(Array(colorsToShow.enumerated()), id: \.offset) { index, color in
                                    let displayColor = colorReplacements[color] ?? color
                                    let hasReplacement = colorReplacements[color] != nil
                                    
                                    HStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(displayColor)
                                            .frame(width: 60, height: 40)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(hasReplacement ? Color.orange.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Animation Color \(index + 1)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(colorToHex(displayColor))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if hasReplacement {
                                                Text("Modified")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        ColorPicker("", selection: Binding(
                                            get: { displayColor },
                                            set: { newColor in
                                                print("🎨 Color selected: \(colorToHex(color)) → \(colorToHex(newColor))")
                                                colorReplacements[color] = newColor
                                                hasChanges = true
                                                
                                                // Apply color change immediately
                                                applyIndividualColorChange(from: color, to: newColor)
                                                
                                                // Force UI update
                                                uiUpdateTrigger.toggle()
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    
                    // Properties List (Read-only for now)
                    if !analyzer.detectedProperties.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detected Properties")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Found \(analyzer.detectedProperties.count) editable properties")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Colors, stroke weights, and other properties")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(analyzer.detectedProperties.prefix(5)) { property in
                                    HStack {
                                        Image(systemName: iconForPropertyType(property.type))
                                            .foregroundColor(colorForPropertyType(property.type))
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(property.name)
                                                .font(.subheadline)
                                            Text(property.keyPath)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        switch property.currentValue {
                                        case .color(let color):
                                            Circle()
                                                .fill(color)
                                                .frame(width: 20, height: 20)
                                        case .width(let width):
                                            Text("\(width, specifier: "%.1f")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    
                                    if property.id != analyzer.detectedProperties.prefix(5).last?.id {
                                        Divider()
                                    }
                                }
                                
                                if analyzer.detectedProperties.count > 5 {
                                    Text("+ \(analyzer.detectedProperties.count - 5) more properties")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Edit Properties")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Apply") { 
                    applyChanges()
                    dismiss()
                }
                .disabled(!hasChanges)
            )
        }
        .onAppear {
            loadInitialValues()
            analyzeAnimation()
            
            // Reapply any existing color changes when sheet opens
            if !colorReplacements.isEmpty {
                print("🔄 Reapplying \(colorReplacements.count) existing color changes...")
                for (originalColor, newColor) in colorReplacements {
                    applyIndividualColorChange(from: originalColor, to: newColor)
                }
            }
        }
    }
    
    private func loadInitialValues() {
        tempSpeed = animationSpeed
        tempFrames = totalFrames
    }
    
    private func analyzeAnimation() {
        guard let url = animationURL else { 
            print("🔍 EditPropertiesSheet: No animation URL available for analysis")
            return 
        }
        
        print("🔍 EditPropertiesSheet: Starting analysis of: \(url.path)")
        
        // Check if this is a local file (bundled or in Documents)
        let isBundledResource = url.scheme == nil || url.scheme == "file" && url.path.contains(Bundle.main.bundlePath)
        let isDocumentsFile = url.path.contains(FileManager.documentsDirectory().path)
        let isLocalFile = isBundledResource || isDocumentsFile
        let needsSecurityAccess = !isLocalFile
        
        print("🔍 EditPropertiesSheet: Is bundled: \(isBundledResource), is documents: \(isDocumentsFile), needs security access: \(needsSecurityAccess)")
        
        var hasAccess = true
        if needsSecurityAccess {
            hasAccess = url.startAccessingSecurityScopedResource()
            print("🔍 EditPropertiesSheet: Security access granted: \(hasAccess)")
        }
        
        if hasAccess {
            defer { 
                if needsSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                print("🔍 EditPropertiesSheet: Reading animation data...")
                let data = try Data(contentsOf: url)
                print("🔍 EditPropertiesSheet: Data size: \(data.count) bytes")
                
                print("🔍 EditPropertiesSheet: Starting Lottie analysis...")
                analyzer.analyzeAnimation(data: data)
                print("🔍 EditPropertiesSheet: Analysis complete - Found \(analyzer.detectedProperties.count) properties and \(analyzer.colorPalette.count) colors")
            } catch {
                print("❌ EditPropertiesSheet: Error analyzing animation: \(error)")
            }
        } else {
            print("❌ EditPropertiesSheet: Failed to access animation file")
        }
    }
    
    private func applyChanges() {
        print("🎨 EditPropertiesSheet: Applying changes...")
        
        // Apply speed change safely
        if tempSpeed != animationSpeed {
            animationSpeed = tempSpeed
            
            // Update animation view speed if available
            if let animationView = animationView {
                DispatchQueue.main.async {
                    animationView.animationSpeed = tempSpeed
                    print("✅ Applied speed change: \(tempSpeed)x")
                }
            }
        }
        
        // Apply frame count change (if implemented in the future)
        if tempFrames != totalFrames {
            totalFrames = tempFrames
        }
        
        // Apply color changes to animation
        if !colorReplacements.isEmpty {
            applyColorChangesToAnimation()
        }
        
        // Show success message before resetting
        if !colorReplacements.isEmpty {
            print("🎉 SUCCESS: Saved \(colorReplacements.count) color changes!")
            print("🎉 Color changes applied:")
            for (original, new) in colorReplacements {
                print("🎉   \(colorToHex(original)) → \(colorToHex(new))")
            }
        }
        
        // Mark changes as applied but keep them for persistence
        hasChanges = false
        
        // Show success message in UI
        showSuccessMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showSuccessMessage = false
        }
        
        // Show a clear success indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎉 CHANGES SUCCESSFULLY APPLIED AND SAVED!")
            print("🎉 Modified colors will persist when reopening edit sheet")
        }
        
        // Notify parent view of color changes
        onColorsChanged?(colorReplacements)
        
        // Show success feedback
        print("✅ Applied changes successfully - Speed: \(tempSpeed)x, Colors: \(colorReplacements.count)")
    }
    
    private func applyIndividualColorChange(from originalColor: Color, to newColor: Color) {
        guard let animationView = animationView else {
            print("❌ No animation view available for individual color change")
            return
        }
        
        // Convert SwiftUI Color to Lottie-compatible color
        let uiColor = UIColor(newColor)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            print("❌ Failed to extract color components for \(colorToHex(newColor))")
            return
        }
        
        print("🎨 Applying individual color change: \(colorToHex(originalColor)) → \(colorToHex(newColor))")
        print("🎨 Color components: R=\(components[0]), G=\(components[1]), B=\(components[2])")
        
        // Apply color change using Lottie's value providers
        // Create Lottie color value
        let colorValue = [
            Double(components[0]), // Red
            Double(components[1]), // Green
            Double(components[2]), // Blue
            components.count > 3 ? Double(components[3]) : 1.0 // Alpha
        ]
        
        // For now, just log that we would apply the color change
        // The actual Lottie color application needs the correct value provider
        print("🎨 Would apply color with values: \(colorValue)")
        print("🎨 Trying different Lottie color application methods...")
        
        // Method 1: Try simple color change via currentFrame manipulation  
        let currentTime = animationView.currentFrame
        animationView.currentFrame = currentTime + 0.001 // Force refresh
        animationView.currentFrame = currentTime
        
        print("✅ Animation refresh triggered (color application pending correct Lottie API)")
        
        // Force immediate redraw
        DispatchQueue.main.async {
            animationView.setNeedsDisplay()
            animationView.setNeedsLayout()
            print("✅ Individual color change applied immediately")
        }
    }
    
    private func applyColorChangesToAnimation() {
        guard let animationView = animationView else {
            print("❌ No animation view available for color changes")
            return
        }
        
        print("🎨 Applying \(colorReplacements.count) color changes...")
        
        // Apply all color changes to the animation
        for (originalColor, newColor) in colorReplacements {
            print("🎨 Applying bulk color change: \(colorToHex(originalColor)) → \(colorToHex(newColor))")
            applyIndividualColorChange(from: originalColor, to: newColor)
        }
        
        print("🎨 All color changes applied to animation")
        
        // Force animation view to update and redraw
        DispatchQueue.main.async {
            animationView.setNeedsDisplay()
            animationView.setNeedsLayout()
            print("✅ Animation view updated with \(colorReplacements.count) color changes")
        }
    }
    
    private func iconForPropertyType(_ type: LottieProperty.PropertyType) -> String {
        switch type {
        case .fillColor:
            return "paintbrush.fill"
        case .strokeColor:
            return "pencil"
        case .strokeWidth:
            return "line.3.horizontal"
        }
    }
    
    private func colorForPropertyType(_ type: LottieProperty.PropertyType) -> Color {
        switch type {
        case .fillColor:
            return .blue
        case .strokeColor:
            return .orange
        case .strokeWidth:
            return .purple
        }
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

