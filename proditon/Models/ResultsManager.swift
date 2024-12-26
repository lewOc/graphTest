import Foundation
import SwiftUI

@MainActor
class ResultsManager: ObservableObject {
    static let shared = ResultsManager()
    
    @Published private(set) var results: [TryOnResult] = []
    
    private let urlSession: URLSession
    private let userDefaults = UserDefaults.standard
    private let resultsKey = "savedTryOnResults"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
        loadResults()
    }
    
    func addResult(imageUrl: String, category: String) async {
        print("Starting to add result: \(imageUrl)")
        
        if let url = URL(string: imageUrl) {
            do {
                let (_, response) = try await urlSession.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("Failed to preload image: \(imageUrl)")
                    return
                }
                
                // Generate ID first so we can use it for both the result and local file
                let resultId = UUID().uuidString
                
                // Save image locally first
                print("💾 Attempting to save image locally...")
                let localPath = await saveImageLocally(imageUrl: imageUrl, id: resultId)
                
                await MainActor.run {
                    let result = TryOnResult(
                        id: resultId,
                        imageUrl: imageUrl,
                        category: category,
                        createdAt: Date(),
                        status: .completed,
                        localImagePath: localPath  // Include local path immediately
                    )
                    results.insert(result, at: 0)
                    saveResults()
                    print("Successfully added and saved result with localPath: \(localPath ?? "none")")
                }
            } catch {
                print("Error preloading image: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshResults() async {
        print("Starting refresh...")
        loadResults()
        
        // Use async let to perform concurrent validation
        await withTaskGroup(of: Void.self) { group in
            for result in results {
                group.addTask {
                    await self.validateResult(result)
                }
            }
        }
        print("Refresh completed")
    }
    
    private func validateResult(_ result: TryOnResult) async {
        guard let url = URL(string: result.imageUrl) else { return }
        
        do {
            let (_, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type for URL: \(result.imageUrl)")
                return
            }
            
            await MainActor.run {
                if httpResponse.statusCode != 200 {
                    print("Invalid status code \(httpResponse.statusCode) for URL: \(result.imageUrl)")
                    if let index = results.firstIndex(where: { $0.id == result.id }) {
                        results.remove(at: index)
                        saveResults()
                    }
                } else {
                    print("Successfully verified URL: \(result.imageUrl)")
                }
            }
        } catch {
            print("Error verifying image URL: \(error.localizedDescription)")
        }
    }
    
    private func verifyLocalFile(_ path: String) -> Bool {
        print("🔍 Verifying local file at: \(path)")
        let fileExists = FileManager.default.fileExists(atPath: path)
        print(fileExists ? "✅ Local file exists" : "❌ Local file missing")
        return fileExists
    }
    
    private var persistentImagesDirectory: URL {
        // Just use Documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("tryons", isDirectory: true)
    }
    
    private func loadResults() {
        if let data = userDefaults.data(forKey: resultsKey),
           let decoded = try? JSONDecoder().decode([TryOnResult].self, from: data) {
            
            // Create persistent directory if needed
            try? FileManager.default.createDirectory(at: persistentImagesDirectory, 
                                                   withIntermediateDirectories: true)
            
            // Update paths to use the persistent directory
            results = decoded.map { result in
                var mutableResult = result
                if result.status == .completed {
                    let filename = "tryon_\(result.id).jpg"
                    let persistentPath = persistentImagesDirectory.appendingPathComponent(filename).path
                    
                    if FileManager.default.fileExists(atPath: persistentPath) {
                        print("✅ Found image in persistent storage: \(persistentPath)")
                        mutableResult.localImagePath = persistentPath
                    } else {
                        print("⚠️ Image missing from persistent storage: \(result.id)")
                        // Only in this case do we need to re-download
                        Task {
                            if let localPath = await saveImageLocally(imageUrl: result.imageUrl, id: result.id) {
                                await MainActor.run {
                                    if let index = results.firstIndex(where: { $0.id == result.id }) {
                                        results[index].localImagePath = localPath
                                        saveResults()
                                    }
                                }
                            }
                        }
                    }
                }
                return mutableResult
            }.sorted(by: { $0.createdAt > $1.createdAt })
            
            print("Loaded \(results.count) results from UserDefaults")
        } else {
            results = []
            print("Loaded 0 results from UserDefaults")
        }
    }
    
    private func saveResults() {
        if let encoded = try? JSONEncoder().encode(results) {
            userDefaults.set(encoded, forKey: resultsKey)
            print("Saved \(results.count) results to UserDefaults")
        } else {
            print("Failed to encode results for saving")
        }
    }
    
    func deleteResult(_ result: TryOnResult) {
        print("🗑️ Attempting to delete result: \(result.id)")
        
        // Delete local file if it exists
        if let localPath = result.localImagePath {
            print("📂 Found local image at: \(localPath)")
            do {
                try FileManager.default.removeItem(atPath: localPath)
                print("✅ Successfully deleted local image file")
            } catch {
                print("❌ Failed to delete local image file: \(error.localizedDescription)")
            }
        }
        
        // Remove from results array
        if let index = results.firstIndex(where: { $0.id == result.id }) {
            results.remove(at: index)
            saveResults()
            print("✅ Successfully removed result from array and saved")
        } else {
            print("❌ Could not find result in array")
        }
    }
    
    func addPendingResult(id: String, category: String) {
        let result = TryOnResult(
            id: id,
            imageUrl: "",  // Will be updated when processing completes
            category: category,
            createdAt: Date(),
            status: .processing
        )
        results.insert(result, at: 0)
        saveResults()
    }
    
    private func saveImageLocally(imageUrl: String, id: String) async -> String? {
        let filename = "tryon_\(id).jpg"
        let imagePath = persistentImagesDirectory.appendingPathComponent(filename)
        
        // Check if image already exists
        if FileManager.default.fileExists(atPath: imagePath.path) {
            print("✅ Image already exists in persistent storage")
            return imagePath.path
        }
        
        print("💾 Downloading image to persistent storage: \(imageUrl)")
        guard let url = URL(string: imageUrl) else {
            print("❌ Invalid URL")
            return nil
        }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create UIImage from data")
                return nil
            }
            
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: imagePath)
                print("✅ Successfully saved image to: \(imagePath.path)")
                return imagePath.path
            }
        } catch {
            print("❌ Error saving image locally: \(error)")
        }
        return nil
    }
    
    func updateResult(id: String, imageUrl: String) async {
        print("⚡️ Updating result with id: \(id), imageUrl: \(imageUrl)")
        if let index = results.firstIndex(where: { $0.id == id }) {
            print("📍 Found result at index: \(index)")
            
            // Save image locally first
            if let localPath = await saveImageLocally(imageUrl: imageUrl, id: id) {
                await MainActor.run {
                    let updatedResult = TryOnResult(
                        id: id,
                        imageUrl: imageUrl,
                        category: results[index].category,
                        createdAt: results[index].createdAt,
                        status: .completed,
                        localImagePath: localPath
                    )
                    results[index] = updatedResult
                    saveResults()
                    print("✅ Updated result with local path: \(localPath)")
                }
            } else {
                print("❌ Failed to save image locally")
                markResultFailed(id: id)
            }
        } else {
            print("❌ Could not find result with id: \(id)")
        }
    }
    
    func markResultFailed(id: String) {
        if let index = results.firstIndex(where: { $0.id == id }) {
            results[index] = TryOnResult(
                id: id,
                imageUrl: "",
                category: results[index].category,
                createdAt: results[index].createdAt,
                status: .failed
            )
            saveResults()
        }
    }
} 