import XCTest
import AVFoundation
@testable import LottieLab

@MainActor
final class LottieLabSmokeTests: XCTestCase {
    func testContentViewCanBeCreated() {
        XCTAssertNotNil(ContentView())
    }

    func testDocumentsDirectoryIsAFileURL() {
        XCTAssertTrue(FileManager.documentsDirectory().isFileURL)
    }

    func testRuntimeComparisonMatrixIsStable() {
        XCTAssertEqual(
            LottieRuntimeVersion.allCases.map(\.rawValue),
            ["3.0.0", "3.5.0", "4.0.0", "4.6.1"]
        )
        XCTAssertEqual(LottieRuntimeVersion.embedded, .v461)
        XCTAssertEqual(LottieRuntimeVersion.v300.shortTitle, "3.0")
        XCTAssertEqual(LottieRuntimeVersion.v461.shortTitle, "4.6")
    }

    func testEveryRuntimeLoadsInsideOnePlayer() throws {
        let player = VersionedLottiePlayerView()
        let data = try JSONSerialization.data(withJSONObject: [
            "v": "5.7.0",
            "fr": 30,
            "ip": 0,
            "op": 60,
            "w": 100,
            "h": 100,
            "layers": [],
        ])

        for runtime in LottieRuntimeVersion.allCases {
            let range = try player.load(data: data, runtime: runtime)
            XCTAssertEqual(player.runtime, runtime)
            XCTAssertEqual(range.start, 0)
            XCTAssertEqual(range.end, 60)
        }
    }

    func testBundledSamplesLoadInEveryRuntime() throws {
        let sampleNames = BundledAnimationsView { _ in }.bundledAnimations
        XCTAssertEqual(sampleNames.count, 6)

        for name in sampleNames {
            let exactURL = Bundle.main.url(forResource: name, withExtension: nil)
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ".json", with: "")
            let url = try XCTUnwrap(
                exactURL ?? Bundle.main.url(forResource: cleanName, withExtension: "json"),
                "Missing bundled sample \(name)"
            )
            let data = try Data(contentsOf: url)
            let document = AnimationDocument()
            try document.load(data: data, sourceURL: url)

            for runtime in LottieRuntimeVersion.allCases {
                let player = VersionedLottiePlayerView()
                XCTAssertNoThrow(
                    try player.load(data: data, runtime: runtime),
                    "\(url.lastPathComponent) failed in lottie-ios \(runtime.rawValue)"
                )
            }
        }
    }

    func testDocumentExtractsMetadataAndDiagnostics() throws {
        let document = AnimationDocument()
        try document.load(data: makeAnimationData(keyframed: true))

        XCTAssertEqual(document.metadata?.formatVersion, "5.12.1")
        XCTAssertEqual(document.metadata?.frameRate, 60)
        XCTAssertEqual(document.metadata?.frameCount, 120)
        XCTAssertEqual(document.metadata?.duration, 2)
        XCTAssertEqual(document.metadata?.width, 200)
        XCTAssertEqual(document.metadata?.height, 100)
        XCTAssertEqual(document.metadata?.layerCount, 1)
        XCTAssertTrue(document.diagnostics.contains { $0.id == "keyframed-colors" })
    }

    func testDocumentAppliesStaticColorReplacement() throws {
        let edits = AnimationEdits(colorReplacements: [
            RGBAColor(red: 1, green: 0, blue: 0): RGBAColor(red: 0, green: 1, blue: 0)
        ])

        let rendered = try AnimationDocument.renderedData(
            from: makeAnimationData(keyframed: false),
            edits: edits
        )

        XCTAssertEqual(try firstColorComponents(in: rendered), [0, 1, 0, 1])
    }

    func testDocumentAppliesKeyframedColorReplacement() throws {
        let edits = AnimationEdits(colorReplacements: [
            RGBAColor(red: 1, green: 0, blue: 0): RGBAColor(red: 0, green: 0, blue: 1)
        ])

        let rendered = try AnimationDocument.renderedData(
            from: makeAnimationData(keyframed: true),
            edits: edits
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: rendered) as? [String: Any]
        )
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let shapes = try XCTUnwrap(layers.first?["shapes"] as? [[String: Any]])
        let color = try XCTUnwrap(shapes.first?["c"] as? [String: Any])
        let keyframes = try XCTUnwrap(color["k"] as? [[String: Any]])

        XCTAssertEqual(keyframes.first?["s"] as? [Double], [0, 0, 1, 1])
        XCTAssertEqual(keyframes.first?["e"] as? [Double], [0, 0, 1, 1])
    }

    func testDocumentAppliesColorReplacementInsidePrecompAsset() throws {
        let data = try makeAnimationWithPrecomp()
        let edits = AnimationEdits(colorReplacements: [
            RGBAColor(red: 0, green: 1, blue: 0): RGBAColor(red: 1, green: 0, blue: 1)
        ])

        let rendered = try AnimationDocument.renderedData(from: data, edits: edits)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: rendered) as? [String: Any]
        )
        let assets = try XCTUnwrap(root["assets"] as? [[String: Any]])
        let layers = try XCTUnwrap(assets.first?["layers"] as? [[String: Any]])
        let shapes = try XCTUnwrap(layers.first?["shapes"] as? [[String: Any]])
        let color = try XCTUnwrap(shapes.first?["c"] as? [String: Any])

        XCTAssertEqual(color["k"] as? [Double], [1, 0, 1, 1])
    }

    func testColorDiscoveryIncludesKeyframesAndPrecomps() throws {
        let colors = try AnimationDocument.discoveredColors(
            in: makeAnimationWithPrecomp()
        )

        XCTAssertTrue(colors.contains(RGBAColor(red: 1, green: 0, blue: 0)))
        XCTAssertTrue(colors.contains(RGBAColor(red: 0, green: 0, blue: 1)))
        XCTAssertTrue(colors.contains(RGBAColor(red: 0, green: 1, blue: 0)))
    }

    func testDocumentKeepsAppliedEditorChanges() throws {
        let document = AnimationDocument()
        try document.load(data: makeAnimationData(keyframed: false))
        let edits = AnimationEdits(
            colorReplacements: [
                RGBAColor(red: 1, green: 0, blue: 0):
                    RGBAColor(red: 0, green: 1, blue: 0)
            ],
            backgroundColor: RGBAColor(red: 0.1, green: 0.2, blue: 0.3),
            playbackSpeed: 1.5
        )

        try document.apply(edits)

        XCTAssertEqual(document.edits, edits)
        XCTAssertNotNil(document.renderedData)
    }

    func testBackgroundBecomesARealLottieSolidLayer() throws {
        let background = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.75)
        let rendered = try AnimationDocument.renderedData(
            from: makeEmptyAnimationData(),
            edits: AnimationEdits(backgroundColor: background)
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: rendered) as? [String: Any]
        )
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let backgroundLayer = try XCTUnwrap(
            layers.first { $0["nm"] as? String == "__LottieLabBackground" }
        )

        XCTAssertEqual(backgroundLayer["ty"] as? Int, 1)
        XCTAssertEqual(backgroundLayer["sc"] as? String, "#336699")
        XCTAssertEqual(backgroundLayer["sw"] as? Int, 200)
        XCTAssertEqual(backgroundLayer["sh"] as? Int, 100)
        let transform = try XCTUnwrap(backgroundLayer["ks"] as? [String: Any])
        let opacity = try XCTUnwrap(transform["o"] as? [String: Any])
        XCTAssertEqual(opacity["k"] as? Double, 75)

        let player = VersionedLottiePlayerView()
        for renderingMode in [LottieRenderingMode.coreAnimation, .mainThread] {
            XCTAssertNoThrow(try player.load(
                data: rendered,
                runtime: .v461,
                renderingMode: renderingMode
            ))
        }
    }

    func testExportPlanCalculatesFramesAndVideoSize() throws {
        let plan = AnimationExportPlan(
            format: .mp4,
            size: CGSize(width: 101, height: 99),
            framesPerSecond: 30,
            duration: 2,
            transparent: false,
            backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
            gifQuality: 0.9
        )

        try plan.validate()
        XCTAssertEqual(plan.frameCount, 60)
        XCTAssertEqual(plan.outputSize, CGSize(width: 102, height: 100))
    }

    func testExportPlanRejectsTransparentMP4() {
        let plan = AnimationExportPlan(
            format: .mp4,
            size: CGSize(width: 100, height: 100),
            framesPerSecond: 30,
            duration: 1,
            transparent: true,
            backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
            gifQuality: 0.9
        )

        XCTAssertThrowsError(try plan.validate()) { error in
            guard case AnimationExportError.transparencyUnsupported(.mp4) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testGIFExporterWritesAFile() async throws {
        let request = AnimationExportRequest(
            animationData: try makeEmptyAnimationData(),
            runtime: .embedded,
            plan: AnimationExportPlan(
                format: .gif,
                size: CGSize(width: 16, height: 16),
                framesPerSecond: 10,
                duration: 0.1,
                transparent: true,
                backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
                gifQuality: 1
            )
        )

        let url = try await AnimationExporter().export(request: request) { _ in }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(
            try Data(contentsOf: url).count,
            0
        )
    }

    func testMP4ExporterWritesAFile() async throws {
        let request = AnimationExportRequest(
            animationData: try makeEmptyAnimationData(),
            runtime: .embedded,
            plan: AnimationExportPlan(
                format: .mp4,
                size: CGSize(width: 16, height: 16),
                framesPerSecond: 10,
                duration: 0.1,
                transparent: false,
                backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
                gifQuality: 1
            )
        )

        let url = try await AnimationExporter().export(request: request) { _ in }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(
            try Data(contentsOf: url).count,
            0
        )

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let descriptions = try await track.load(.formatDescriptions)
        let description = try XCTUnwrap(descriptions.first)
        XCTAssertEqual(
            CMFormatDescriptionGetMediaSubType(description),
            kCMVideoCodecType_H264
        )
    }

    func testTransparentMOVExporterUsesHEVCWithAlpha() async throws {
        let request = AnimationExportRequest(
            animationData: try makeEmptyAnimationData(),
            runtime: .embedded,
            plan: AnimationExportPlan(
                format: .mov,
                size: CGSize(width: 16, height: 16),
                framesPerSecond: 10,
                duration: 0.1,
                transparent: true,
                backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
                gifQuality: 1
            )
        )

        do {
            let url = try await AnimationExporter().export(request: request) { _ in }
            defer { try? FileManager.default.removeItem(at: url) }

            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first)
            let descriptions = try await track.load(.formatDescriptions)
            let description = try XCTUnwrap(descriptions.first)

            XCTAssertEqual(url.pathExtension, "mov")
            XCTAssertEqual(
                CMFormatDescriptionGetMediaSubType(description),
                kCMVideoCodecType_HEVCWithAlpha
            )
        } catch AnimationExportError.alphaEncodingUnavailable {
            // Simulator configurations without an alpha-capable HEVC encoder
            // must fail explicitly instead of returning an opaque video.
        }
    }

    func testExportCancellationRemovesPartialFile() async throws {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let filesBefore = try Set(
            FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("LottieLab-") }
        )
        let request = AnimationExportRequest(
            animationData: try makeEmptyAnimationData(),
            runtime: .embedded,
            plan: AnimationExportPlan(
                format: .gif,
                size: CGSize(width: 128, height: 128),
                framesPerSecond: 60,
                duration: 10,
                transparent: true,
                backgroundColor: RGBAColor(red: 1, green: 1, blue: 1),
                gifQuality: 1
            )
        )

        let task = Task { @MainActor in
            try await AnimationExporter().export(request: request) { _ in }
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Export should have been cancelled.")
        } catch is CancellationError {
            // Expected.
        }

        let filesAfter = try Set(
            FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("LottieLab-") }
        )
        XCTAssertEqual(filesAfter, filesBefore)
    }

    private func makeAnimationData(keyframed: Bool) throws -> Data {
        let colorValue: Any = keyframed
            ? [["t": 0, "s": [1.0, 0.0, 0.0, 1.0], "e": [1.0, 0.0, 0.0, 1.0]]]
            : [1.0, 0.0, 0.0, 1.0]
        let json: [String: Any] = [
            "v": "5.12.1",
            "fr": 60,
            "ip": 0,
            "op": 120,
            "w": 200,
            "h": 100,
            "layers": [[
                "ty": 4,
                "shapes": [[
                    "ty": "fl",
                    "c": ["a": keyframed ? 1 : 0, "k": colorValue],
                    "o": ["a": 0, "k": 100],
                    "r": 1,
                ]]
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: json)
    }

    private func makeEmptyAnimationData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "v": "5.7.0",
            "fr": 30,
            "ip": 0,
            "op": 60,
            "w": 200,
            "h": 100,
            "layers": [],
        ])
    }

    private func makeAnimationWithPrecomp() throws -> Data {
        let json: [String: Any] = [
            "v": "5.12.1",
            "fr": 30,
            "ip": 0,
            "op": 60,
            "w": 100,
            "h": 100,
            "layers": [[
                "ty": 4,
                "shapes": [[
                    "ty": "fl",
                    "c": [
                        "a": 1,
                        "k": [[
                            "t": 0,
                            "s": [1.0, 0.0, 0.0, 1.0],
                            "e": [0.0, 0.0, 1.0, 1.0],
                        ]],
                    ],
                ]],
            ]],
            "assets": [[
                "id": "precomp_1",
                "layers": [[
                    "ty": 4,
                    "shapes": [[
                        "ty": "st",
                        "c": ["a": 0, "k": [0.0, 1.0, 0.0, 1.0]],
                    ]],
                ]],
            ]],
        ]
        return try JSONSerialization.data(withJSONObject: json)
    }

    private func firstColorComponents(in data: Data) throws -> [Double] {
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let shapes = try XCTUnwrap(layers.first?["shapes"] as? [[String: Any]])
        let color = try XCTUnwrap(shapes.first?["c"] as? [String: Any])
        return try XCTUnwrap(color["k"] as? [Double])
    }
}
