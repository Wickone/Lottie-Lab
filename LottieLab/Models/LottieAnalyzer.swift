import Foundation
import SwiftUI

struct LottieProperty: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let keyPath: String
    let type: PropertyType
    let currentValue: PropertyValue
    
    enum PropertyType: Hashable {
        case fillColor
        case strokeColor
        case strokeWidth
    }
    
    enum PropertyValue: Hashable {
        case color(Color)
        case width(Double)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .color(let color):
                hasher.combine("color")
                hasher.combine(color)
            case .width(let width):
                hasher.combine("width")
                hasher.combine(width)
            }
        }
        
        static func == (lhs: PropertyValue, rhs: PropertyValue) -> Bool {
            switch (lhs, rhs) {
            case (.color(let color1), .color(let color2)):
                return color1 == color2
            case (.width(let width1), .width(let width2)):
                return width1 == width2
            default:
                return false
            }
        }
    }
}

class LottieAnalyzer: ObservableObject {
    @Published var detectedProperties: [LottieProperty] = []
    @Published var colorPalette: [Color] = []
    
    func analyzeAnimation(data: Data) {
        print("🔍 LottieAnalyzer: Starting analysis of \(data.count) bytes")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ LottieAnalyzer: Failed to parse JSON")
            return
        }
        
        print("🔍 LottieAnalyzer: JSON parsed successfully")
        
        var properties: [LottieProperty] = []
        var colors: Set<Color> = []
        
        // Parse layers
        if let layers = json["layers"] as? [[String: Any]] {
            print("🔍 LottieAnalyzer: Found \(layers.count) layers")
            
            for (layerIndex, layer) in layers.enumerated() {
                let layerName = layer["nm"] as? String ?? "Layer \(layerIndex)"
                let layerType = layer["ty"] as? Int ?? -1
                print("🔍 LottieAnalyzer: Processing layer \(layerIndex): \(layerName) (type: \(layerType))")
                
                // Parse shapes in layer
                if let shapes = layer["shapes"] as? [[String: Any]] {
                    print("🔍 LottieAnalyzer: Layer \(layerIndex) has \(shapes.count) shapes")
                    properties.append(contentsOf: parseShapes(shapes, layerName: layerName, colors: &colors))
                } else {
                    print("🔍 LottieAnalyzer: Layer \(layerIndex) has no shapes array")
                }
            }
        } else {
            print("❌ LottieAnalyzer: No layers found in JSON")
        }
        
        print("🔍 LottieAnalyzer: Analysis complete - \(properties.count) properties, \(colors.count) colors")
        
        DispatchQueue.main.async {
            self.detectedProperties = properties
            self.colorPalette = Array(colors)
            print("🔍 LottieAnalyzer: Updated UI with \(self.detectedProperties.count) properties and \(self.colorPalette.count) colors")
        }
    }
    
    private func parseShapes(_ shapes: [[String: Any]], layerName: String, colors: inout Set<Color>) -> [LottieProperty] {
        var properties: [LottieProperty] = []
        
        print("🔍 LottieAnalyzer: parseShapes called with \(shapes.count) shapes for layer: \(layerName)")
        
        for (shapeIndex, shape) in shapes.enumerated() {
            let shapeName = shape["nm"] as? String ?? "Shape \(shapeIndex)"
            let shapeType = shape["ty"] as? String ?? ""
            
            print("🔍 LottieAnalyzer: Processing shape \(shapeIndex): \(shapeName) (type: \(shapeType))")
            
            switch shapeType {
            case "fl": // Fill
                print("🔍 LottieAnalyzer: Found fill shape, extracting color...")
                if let fillColor = extractColor(from: shape["c"]) {
                    colors.insert(fillColor)
                    let fillName = shape["nm"] as? String ?? "Fill"
                    properties.append(LottieProperty(
                        name: "\(layerName) - \(fillName)",
                        keyPath: "**.Fill.Color",
                        type: .fillColor,
                        currentValue: .color(fillColor)
                    ))
                    print("✅ LottieAnalyzer: Added fill color property")
                } else {
                    print("❌ LottieAnalyzer: Failed to extract fill color")
                }
                
            case "st": // Stroke
                print("🔍 LottieAnalyzer: Found stroke shape, extracting color and width...")
                if let strokeColor = extractColor(from: shape["c"]) {
                    colors.insert(strokeColor)
                    let strokeName = shape["nm"] as? String ?? "Stroke"
                    properties.append(LottieProperty(
                        name: "\(layerName) - \(strokeName) Color",
                        keyPath: "**.Stroke.Color",
                        type: .strokeColor,
                        currentValue: .color(strokeColor)
                    ))
                    print("✅ LottieAnalyzer: Added stroke color property")
                } else {
                    print("❌ LottieAnalyzer: Failed to extract stroke color")
                }
                
                if let strokeWidth = extractStrokeWidth(from: shape["w"]) {
                    let strokeName = shape["nm"] as? String ?? "Stroke"
                    properties.append(LottieProperty(
                        name: "\(layerName) - \(strokeName) Width",
                        keyPath: "**.Stroke.Stroke Width",
                        type: .strokeWidth,
                        currentValue: .width(strokeWidth)
                    ))
                    print("✅ LottieAnalyzer: Added stroke width property")
                } else {
                    print("❌ LottieAnalyzer: Failed to extract stroke width")
                }
                
            case "gr": // Group
                print("🔍 LottieAnalyzer: Found group shape, processing nested items...")
                if let groupItems = shape["it"] as? [[String: Any]] {
                    let nestedProperties = parseShapes(groupItems, layerName: "\(layerName).\(shapeName)", colors: &colors)
                    properties.append(contentsOf: nestedProperties)
                    print("✅ LottieAnalyzer: Added \(nestedProperties.count) properties from group")
                }
                
            default:
                print("🔍 LottieAnalyzer: Unknown shape type \(shapeType), checking for items...")
                // Handle other shape types if needed
                if let items = shape["it"] as? [[String: Any]] {
                    let nestedProperties = parseShapes(items, layerName: "\(layerName).\(shapeName)", colors: &colors)
                    properties.append(contentsOf: nestedProperties)
                    print("✅ LottieAnalyzer: Added \(nestedProperties.count) properties from unknown shape type")
                }
            }
        }
        
        print("🔍 LottieAnalyzer: parseShapes returning \(properties.count) properties")
        return properties
    }
    
    private func extractColor(from colorData: Any?) -> Color? {
        print("🔍 LottieAnalyzer: extractColor called with: \(String(describing: colorData))")
        
        guard let colorInfo = colorData as? [String: Any] else { 
            print("❌ LottieAnalyzer: colorData is not a dictionary")
            return nil 
        }
        
        print("🔍 LottieAnalyzer: colorInfo keys: \(colorInfo.keys)")
        
        // Handle both animated and static colors
        if let colorArray = colorInfo["k"] as? [Double], colorArray.count >= 3 {
            let color = Color(
                red: colorArray[0],
                green: colorArray[1],
                blue: colorArray[2],
                opacity: colorArray.count > 3 ? colorArray[3] : 1.0
            )
            print("✅ LottieAnalyzer: Extracted static color: \(colorArray)")
            return color
        }
        
        // Handle animated colors (take first keyframe)
        if let keyframes = colorInfo["k"] as? [[String: Any]],
           let firstFrame = keyframes.first,
           let startValue = firstFrame["s"] as? [Double],
           startValue.count >= 3 {
            let color = Color(
                red: startValue[0],
                green: startValue[1],
                blue: startValue[2],
                opacity: startValue.count > 3 ? startValue[3] : 1.0
            )
            print("✅ LottieAnalyzer: Extracted animated color: \(startValue)")
            return color
        }
        
        print("❌ LottieAnalyzer: Failed to extract color from data")
        return nil
    }
    
    private func extractStrokeWidth(from widthData: Any?) -> Double? {
        guard let widthInfo = widthData as? [String: Any] else { return nil }
        
        // Handle static width
        if let width = widthInfo["k"] as? Double {
            return width
        }
        
        // Handle animated width (take first keyframe)
        if let keyframes = widthInfo["k"] as? [[String: Any]],
           let firstFrame = keyframes.first,
           let startValue = firstFrame["s"] as? [Double],
           let width = startValue.first {
            return width
        }
        
        return nil
    }
}