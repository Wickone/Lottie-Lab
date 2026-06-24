import Foundation
import SwiftUI

struct RGBAColor: Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }

    init?(components: [Double]) {
        guard components.count >= 3 else { return nil }
        self.init(
            red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components.count > 3 ? components[3] : 1
        )
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var components: [Double] {
        [red, green, blue, alpha]
    }

    var hexRGB: String {
        let red = Int((min(max(red, 0), 1) * 255).rounded())
        let green = Int((min(max(green, 0), 1) * 255).rounded())
        let blue = Int((min(max(blue, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    func isApproximatelyEqual(to components: [Double], tolerance: Double = 0.001) -> Bool {
        guard let other = RGBAColor(components: components) else { return false }
        return abs(red - other.red) < tolerance
            && abs(green - other.green) < tolerance
            && abs(blue - other.blue) < tolerance
            && abs(alpha - other.alpha) < tolerance
    }
}

struct AnimationMetadata: Equatable {
    let formatVersion: String?
    let frameRate: Double
    let startFrame: Double
    let endFrame: Double
    let width: Int
    let height: Int
    let layerCount: Int
    let assetCount: Int

    var frameCount: Double {
        max(0, endFrame - startFrame)
    }

    var duration: Double {
        guard frameRate > 0 else { return 0 }
        return frameCount / frameRate
    }
}

struct AnimationEdits: Equatable {
    var colorReplacements: [RGBAColor: RGBAColor] = [:]
    var backgroundColor: RGBAColor?
    var playbackSpeed: Double = 1

    var isEmpty: Bool {
        colorReplacements.isEmpty && backgroundColor == nil && playbackSpeed == 1
    }
}

struct AnimationDiagnostic: Identifiable, Equatable {
    enum Severity: String {
        case info
        case warning
        case error
    }

    let id: String
    let severity: Severity
    let message: String
}

enum AnimationDocumentError: LocalizedError {
    case invalidRootObject
    case missingLayers

    var errorDescription: String? {
        switch self {
        case .invalidRootObject:
            return "The selected file is not a valid Lottie JSON object."
        case .missingLayers:
            return "The selected JSON does not contain a Lottie layers array."
        }
    }
}

@MainActor
final class AnimationDocument: ObservableObject {
    @Published private(set) var sourceURL: URL?
    @Published private(set) var originalData: Data?
    @Published private(set) var metadata: AnimationMetadata?
    @Published private(set) var diagnostics: [AnimationDiagnostic] = []
    @Published private(set) var edits = AnimationEdits()
    @Published var selectedRuntime: LottieRuntimeVersion = .embedded

    var isLoaded: Bool {
        originalData != nil && metadata != nil
    }

    var displayName: String {
        sourceURL?.deletingPathExtension().lastPathComponent ?? "Untitled Animation"
    }

    var renderedData: Data? {
        guard let originalData else { return nil }
        return try? Self.renderedData(from: originalData, edits: edits)
    }

    func load(from url: URL) throws {
        let data = try Self.readData(from: url)
        try load(data: data, sourceURL: url)
    }

    func load(data: Data, sourceURL: URL? = nil) throws {
        let root = try Self.rootObject(from: data)
        guard root["layers"] is [[String: Any]] else {
            throw AnimationDocumentError.missingLayers
        }

        self.sourceURL = sourceURL
        originalData = data
        metadata = Self.makeMetadata(from: root)
        diagnostics = Self.makeDiagnostics(from: root)
        edits = AnimationEdits()
        selectedRuntime = .embedded
    }

    func updateColorReplacements(_ replacements: [Color: Color]) {
        edits.colorReplacements = Dictionary(
            uniqueKeysWithValues: replacements.map { (RGBAColor($0.key), RGBAColor($0.value)) }
        )
    }

    func updateBackgroundColor(_ color: Color?) {
        edits.backgroundColor = color.map(RGBAColor.init)
    }

    func updatePlaybackSpeed(_ speed: Double) {
        edits.playbackSpeed = speed
    }

    func apply(_ newEdits: AnimationEdits) throws {
        guard let originalData else {
            throw AnimationDocumentError.invalidRootObject
        }

        _ = try Self.renderedData(from: originalData, edits: newEdits)
        edits = newEdits
    }

    var colorReplacementsForUI: [Color: Color] {
        Dictionary(
            uniqueKeysWithValues: edits.colorReplacements.map {
                ($0.key.swiftUIColor, $0.value.swiftUIColor)
            }
        )
    }

    static func renderedData(from data: Data, edits: AnimationEdits) throws -> Data {
        var root = try rootObject(from: data)
        root = apply(edits: edits, to: root)
        return try JSONSerialization.data(withJSONObject: root, options: [])
    }

    static func discoveredColors(in data: Data) throws -> [RGBAColor] {
        let root = try rootObject(from: data)
        var colors: [RGBAColor] = []
        collectColors(in: root, into: &colors)

        return colors.reduce(into: []) { result, color in
            if !result.contains(where: { approximatelyEqual($0, color) }) {
                result.append(color)
            }
        }
    }

    private static func readData(from url: URL) throws -> Data {
        let isBundled = url.path.contains(Bundle.main.bundlePath)
        let isInDocuments = url.path.contains(FileManager.documentsDirectory().path)
        let needsSecurityAccess = !isBundled && !isInDocuments
        let hasAccess = !needsSecurityAccess || url.startAccessingSecurityScopedResource()

        guard hasAccess else {
            throw CocoaError(.fileReadNoPermission)
        }

        defer {
            if needsSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: url)
    }

    private static func rootObject(from data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnimationDocumentError.invalidRootObject
        }
        return root
    }

    private static func makeMetadata(from root: [String: Any]) -> AnimationMetadata {
        let layers = root["layers"] as? [[String: Any]] ?? []
        let assets = root["assets"] as? [[String: Any]] ?? []

        return AnimationMetadata(
            formatVersion: root["v"] as? String,
            frameRate: number(root["fr"]),
            startFrame: number(root["ip"]),
            endFrame: number(root["op"]),
            width: Int(number(root["w"])),
            height: Int(number(root["h"])),
            layerCount: layers.count,
            assetCount: assets.count
        )
    }

    private static func makeDiagnostics(from root: [String: Any]) -> [AnimationDiagnostic] {
        var result: [AnimationDiagnostic] = []

        if root["v"] as? String == nil {
            result.append(.init(
                id: "missing-version",
                severity: .warning,
                message: "The Lottie format version is missing."
            ))
        }

        if number(root["fr"]) <= 0 {
            result.append(.init(
                id: "invalid-frame-rate",
                severity: .error,
                message: "Frame rate must be greater than zero."
            ))
        }

        if number(root["op"]) <= number(root["ip"]) {
            result.append(.init(
                id: "invalid-frame-range",
                severity: .error,
                message: "The animation end frame must be after its start frame."
            ))
        }

        if containsExpressions(in: root) {
            result.append(.init(
                id: "expressions",
                severity: .warning,
                message: "Expressions were detected and may not render consistently."
            ))
        }

        if containsKeyframedColors(in: root) {
            result.append(.init(
                id: "keyframed-colors",
                severity: .info,
                message: "The animation contains keyframed colors."
            ))
        }

        return result
    }

    private static func apply(edits: AnimationEdits, to root: [String: Any]) -> [String: Any] {
        var updated = root

        if let layers = root["layers"] as? [[String: Any]] {
            updated["layers"] = layers.map {
                processLayer($0, replacements: edits.colorReplacements)
            }
        }

        if let assets = root["assets"] as? [[String: Any]] {
            updated["assets"] = assets.map { asset in
                var updatedAsset = asset
                if let layers = asset["layers"] as? [[String: Any]] {
                    updatedAsset["layers"] = layers.map {
                        processLayer($0, replacements: edits.colorReplacements)
                    }
                }
                return updatedAsset
            }
        }

        applyBackground(edits.backgroundColor, to: &updated)
        return updated
    }

    private static func applyBackground(
        _ backgroundColor: RGBAColor?,
        to root: inout [String: Any]
    ) {
        let layerName = "__LottieLabBackground"
        var layers = (root["layers"] as? [[String: Any]] ?? []).filter {
            $0["nm"] as? String != layerName
        }

        guard let backgroundColor else {
            root["layers"] = layers
            return
        }

        let width = max(1, Int(number(root["w"])))
        let height = max(1, Int(number(root["h"])))
        let startFrame = number(root["ip"])
        let endFrame = number(root["op"])
        let maximumIndex = layers.compactMap { ($0["ind"] as? NSNumber)?.intValue }.max() ?? 0

        let backgroundLayer: [String: Any] = [
            "ddd": 0,
            "ind": maximumIndex + 1,
            "ty": 1,
            "nm": layerName,
            "sr": 1,
            "ks": [
                "o": ["a": 0, "k": backgroundColor.alpha * 100],
                "r": ["a": 0, "k": 0],
                "p": ["a": 0, "k": [Double(width) / 2, Double(height) / 2, 0]],
                "a": ["a": 0, "k": [Double(width) / 2, Double(height) / 2, 0]],
                "s": ["a": 0, "k": [100, 100, 100]],
            ],
            "ao": 0,
            "sw": width,
            "sh": height,
            "sc": backgroundColor.hexRGB,
            "ip": startFrame,
            "op": endFrame,
            "st": startFrame,
            "bm": 0,
        ]

        layers.append(backgroundLayer)
        root["layers"] = layers
    }

    private static func processLayer(
        _ layer: [String: Any],
        replacements: [RGBAColor: RGBAColor]
    ) -> [String: Any] {
        var updated = layer
        if let shapes = layer["shapes"] as? [[String: Any]] {
            updated["shapes"] = shapes.map {
                processShape($0, replacements: replacements)
            }
        }
        return updated
    }

    private static func processShape(
        _ shape: [String: Any],
        replacements: [RGBAColor: RGBAColor]
    ) -> [String: Any] {
        var updated = shape

        if let type = shape["ty"] as? String,
           type == "fl" || type == "st",
           var color = shape["c"] as? [String: Any] {
            color["k"] = replaceColorValue(color["k"], replacements: replacements)
            updated["c"] = color
        }

        if let items = shape["it"] as? [[String: Any]] {
            updated["it"] = items.map {
                processShape($0, replacements: replacements)
            }
        }

        return updated
    }

    private static func replaceColorValue(
        _ value: Any?,
        replacements: [RGBAColor: RGBAColor]
    ) -> Any? {
        if let components = colorComponents(from: value) {
            return replacementComponents(
                for: components,
                in: replacements
            ) ?? components
        }

        guard let keyframes = value as? [[String: Any]] else {
            return value
        }

        return keyframes.map { keyframe in
            var updated = keyframe
            for key in ["s", "e"] {
                if let components = colorComponents(from: keyframe[key]),
                   let replacement = replacementComponents(
                       for: components,
                       in: replacements
                   ) {
                    updated[key] = replacement
                }
            }
            return updated
        }
    }

    private static func replacementComponents(
        for components: [Double],
        in replacements: [RGBAColor: RGBAColor]
    ) -> [Double]? {
        guard let replacement = replacement(for: components, in: replacements) else {
            return nil
        }

        return components.count == 3
            ? Array(replacement.components.prefix(3))
            : replacement.components
    }

    private static func replacement(
        for components: [Double],
        in replacements: [RGBAColor: RGBAColor]
    ) -> RGBAColor? {
        replacements.first { original, _ in
            original.isApproximatelyEqual(to: components)
        }?.value
    }

    private static func collectColors(in value: Any, into colors: inout [RGBAColor]) {
        if let dictionary = value as? [String: Any] {
            if let type = dictionary["ty"] as? String,
               (type == "fl" || type == "st"),
               let color = dictionary["c"] as? [String: Any] {
                collectColorValues(from: color["k"], into: &colors)
            }

            for nestedValue in dictionary.values {
                collectColors(in: nestedValue, into: &colors)
            }
        } else if let array = value as? [Any] {
            for nestedValue in array {
                collectColors(in: nestedValue, into: &colors)
            }
        }
    }

    private static func collectColorValues(from value: Any?, into colors: inout [RGBAColor]) {
        if let components = colorComponents(from: value),
           let color = RGBAColor(components: components) {
            colors.append(color)
            return
        }

        guard let keyframes = value as? [[String: Any]] else { return }
        for keyframe in keyframes {
            for key in ["s", "e"] {
                if let components = colorComponents(from: keyframe[key]),
                   let color = RGBAColor(components: components) {
                    colors.append(color)
                }
            }
        }
    }

    private static func colorComponents(from value: Any?) -> [Double]? {
        if let values = value as? [NSNumber], values.count >= 3 {
            return values.map(\.doubleValue)
        }
        if let values = value as? [Double], values.count >= 3 {
            return values
        }
        return nil
    }

    private static func approximatelyEqual(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Bool {
        lhs.isApproximatelyEqual(to: rhs.components)
    }

    private static func containsExpressions(in value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if dictionary["x"] is String {
                return true
            }
            return dictionary.values.contains(where: containsExpressions)
        }
        if let array = value as? [Any] {
            return array.contains(where: containsExpressions)
        }
        return false
    }

    private static func containsKeyframedColors(in value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if let type = dictionary["ty"] as? String,
               (type == "fl" || type == "st"),
               let color = dictionary["c"] as? [String: Any],
               color["k"] is [[String: Any]] {
                return true
            }
            return dictionary.values.contains(where: containsKeyframedColors)
        }
        if let array = value as? [Any] {
            return array.contains(where: containsKeyframedColors)
        }
        return false
    }

    private static func number(_ value: Any?) -> Double {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return 0
    }
}
