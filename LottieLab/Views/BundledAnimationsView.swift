import SwiftUI
import UniformTypeIdentifiers

struct BundledAnimationsView: View {
    @Binding var selectedAnimationURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var loadingAnimation: String? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    
    let bundledAnimations = [
        "note_outline_music_sa_outline_to_fill_28.json ",
        "compass_music_sa_outline_to_fill_28 2.json",
        "heart_list_music_sa_outline_to_fill_28.json",
        "horse_toy_outline_music_sa_outline_to_fill_28.json",
        "podcast_books_outline_music_sa_outline_to_fill_28.json",
        "radio_outline_music_sa_outline_to_fill_28.json"
    ]
    
    var body: some View {
        NavigationView {
            List(bundledAnimations, id: \.self) { animationName in
                HStack {
                    VStack(alignment: .leading) {
                        Text(animationName)
                            .font(.headline)
                        Text("Bundled Animation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        print("🔘 BundledAnimationsView: Load button tapped for: \(animationName)")
                        loadingAnimation = animationName
                        loadBundledAnimation(named: animationName)
                    }) {
                        if loadingAnimation == animationName {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading")
                            }
                        } else {
                            Text("Load")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(loadingAnimation != nil)
                }
            }
            .navigationTitle("Sample Animations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        if isImporting {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Importing")
                            }
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(isImporting)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .alert("Import Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadBundledAnimation(named name: String) {
        print("🔍 Attempting to load bundled animation: '\(name)'")
        
        // First try with the exact name (might include extension)
        var url = Bundle.main.url(forResource: name, withExtension: nil)
        print("🔍 Try 1 - Exact name: \(url?.path ?? "not found")")
        
        // If not found, try with .json extension
        if url == nil {
            url = Bundle.main.url(forResource: name, withExtension: "json")
            print("🔍 Try 2 - With .json extension: \(url?.path ?? "not found")")
        }
        
        // Try removing any trailing spaces and extensions
        if url == nil {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ".json", with: "")
            url = Bundle.main.url(forResource: cleanName, withExtension: "json")
            print("🔍 Try 3 - Clean name '\(cleanName)': \(url?.path ?? "not found")")
        }
        
        guard let animationURL = url else {
            print("❌ Could not find bundled animation: '\(name)'")
            print("❌ Searched for: '\(name)', '\(name).json'")
            // List all available bundle resources for debugging
            if let bundlePath = Bundle.main.resourcePath {
                print("📁 Bundle contents:")
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                    for file in contents.filter({ $0.contains(".json") }) {
                        print("  - \(file)")
                    }
                } catch {
                    print("❌ Could not list bundle contents: \(error)")
                }
            }
            return
        }
        
        print("✅ Found bundled animation at: \(animationURL.path)")
        
        // Provide immediate feedback
        DispatchQueue.main.async {
            self.selectedAnimationURL = animationURL
            
            // Clear loading state and dismiss after a brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadingAnimation = nil
                self.dismiss()
            }
        }
    }
    
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        // Ensure we're on main queue for UI updates
        DispatchQueue.main.async {
            self.isImporting = true
            
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    print("❌ No URL selected")
                    self.isImporting = false
                    return
                }
                print("📁 File import attempt: \(url.path)")
                print("📁 URL scheme: \(url.scheme ?? "none")")
                print("📁 Is file URL: \(url.isFileURL)")
                
                // Run import on background queue to avoid blocking UI
                DispatchQueue.global(qos: .userInitiated).async {
                    self.importFile(from: url)
                }
                
            case .failure(let error):
                print("❌ File picker failed: \(error.localizedDescription)")
                self.showImportError("File selection failed: \(error.localizedDescription)")
                self.isImporting = false
            }
        }
    }
    
    private func importFile(from url: URL) {
        print("🔐 Starting import for: \(url.path)")
        
        // Check if this is a local file that doesn't need security access
        let isDocumentsFile = url.path.contains(FileManager.documentsDirectory().path)
        let isBundledFile = url.path.contains(Bundle.main.bundlePath)
        let isLocalFile = isDocumentsFile || isBundledFile
        
        // Only request security access for external files
        let hasSecurityAccess: Bool
        if isLocalFile {
            hasSecurityAccess = true
            print("🔐 Local file, no security access needed")
        } else {
            hasSecurityAccess = url.startAccessingSecurityScopedResource()
            print("🔐 External file, security access: \(hasSecurityAccess)")
        }
        
        defer {
            if !isLocalFile && hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
                print("🔐 Security access released")
            }
        }
        
        do {
            print("📖 Reading file data...")
            
            // Check if file exists and is readable
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let isReadable = FileManager.default.isReadableFile(atPath: url.path)
            
            print("📁 File exists: \(fileExists)")
            print("📁 File readable: \(isReadable)")
            
            if !fileExists {
                throw NSError(domain: "FileImportError", code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "The selected file does not exist"])
            }
            
            if !isReadable {
                throw NSError(domain: "FileImportError", code: NSFileReadNoPermissionError, userInfo: [NSLocalizedDescriptionKey: "The selected file is not readable"])
            }
            
            // Try to read the file data
            let data = try Data(contentsOf: url)
            print("✅ Read \(data.count) bytes")
            
            // Validate it's a valid JSON and looks like a Lottie file
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            // Basic Lottie validation
            if let dict = jsonObject as? [String: Any] {
                let hasVersion = dict["v"] != nil
                let hasFrameRate = dict["fr"] != nil
                let hasLayers = dict["layers"] != nil
                
                if hasVersion || hasFrameRate || hasLayers {
                    print("✅ File appears to be a valid Lottie animation")
                } else {
                    print("⚠️ File might not be a Lottie animation, but proceeding...")
                }
            }
            
            // Always copy to Documents to ensure we have local access
            let fileName = generateUniqueFileName(from: url.lastPathComponent)
            let documentsURL = FileManager.documentsDirectory()
            let destinationURL = documentsURL.appendingPathComponent(fileName)
            
            print("💾 Copying to: \(destinationURL.path)")
            
            // Copy the file to Documents directory
            try data.write(to: destinationURL)
            let finalURL = destinationURL
            
            print("✅ File imported successfully")
            
            // Set the animation URL to the final file location
            DispatchQueue.main.async {
                self.selectedAnimationURL = finalURL
                self.isImporting = false
                self.dismiss()
            }
            
        } catch {
            print("❌ Import error: \(error)")
            
            let errorMessage: String
            if let nsError = error as NSError? {
                switch nsError.code {
                case NSFileReadNoSuchFileError:
                    errorMessage = "File not found. The file may have been moved or deleted."
                case NSFileReadNoPermissionError:
                    errorMessage = "Permission denied. Unable to read the selected file."
                case NSFileReadCorruptFileError:
                    errorMessage = "The file appears to be corrupted and cannot be read."
                default:
                    errorMessage = "Failed to import file: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to import file: \(error.localizedDescription)"
            }
            
            showImportError(errorMessage)
        }
    }
    
    private func generateUniqueFileName(from originalName: String) -> String {
        let documentsURL = FileManager.documentsDirectory()
        var fileName = originalName
        var counter = 1
        
        // Ensure the filename has .json extension
        if !fileName.lowercased().hasSuffix(".json") {
            fileName += ".json"
        }
        
        // Check if file already exists and add counter if needed
        while FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent(fileName).path) {
            let nameWithoutExtension = (originalName as NSString).deletingPathExtension
            fileName = "\(nameWithoutExtension)_\(counter).json"
            counter += 1
        }
        
        return fileName
    }
    
    private func showImportError(_ message: String) {
        print("🚨 Import Error: \(message)")
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showingAlert = true
            self.isImporting = false
        }
    }
}