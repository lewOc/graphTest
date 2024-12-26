import SwiftUI
import PhotosUI

struct OutfitTryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @StateObject private var resultsManager = ResultsManager.shared
    
    @State private var baseImage: UIImage?
    @State private var baseImageSelection: PhotosPickerItem?
    @State private var selectedTop: ClothingItem?
    @State private var selectedBottom: ClothingItem?
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Base Image Selection
                    ImageSelectionBox(
                        title: "Your Photo",
                        image: baseImage,
                        imageSelection: $baseImageSelection
                    )
                    .onChange(of: baseImageSelection) { oldValue, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                baseImage = image
                            }
                        }
                    }
                    
                    // Top Selection
                    VStack(alignment: .leading) {
                        Text("Select Top")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(wardrobeManager.items.filter { $0.category == .top }) { item in
                                    WardrobeItemView(item: item, isSelected: item.id == selectedTop?.id)
                                        .onTapGesture {
                                            selectedTop = item
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Bottom Selection
                    VStack(alignment: .leading) {
                        Text("Select Bottom")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(wardrobeManager.items.filter { $0.category == .bottom }) { item in
                                    WardrobeItemView(item: item, isSelected: item.id == selectedBottom?.id)
                                        .onTapGesture {
                                            selectedBottom = item
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await performOutfitTryOn()
                        }
                    }) {
                        Text("Try On Outfit")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(baseImage == nil || selectedTop == nil || selectedBottom == nil || isLoading)
                }
                .padding()
            }
            .navigationTitle("Try On Wardrobe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    LoadingView(message: loadingMessage)
                }
            }
            .alert("Error", isPresented: $showError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage ?? "An unknown error occurred")
            })
        }
    }
    
    private func performOutfitTryOn() async {
        guard let baseImage = baseImage,
              let topItem = selectedTop,
              let bottomItem = selectedBottom else {
            errorMessage = "Please select all required images"
            showError = true
            return
        }
        
        // Create temporary outfit immediately
        let outfit = await wardrobeManager.addOutfitInProgress(
            topItem: topItem,
            bottomItem: bottomItem
        )
        
        // Dismiss immediately
        dismiss()
        
        // Process in background with timeout
        Task.detached {
            do {
                try await withTimeout(seconds: 120) {
                    // First try-on with top
                    let topResult = try await performSingleTryOn(
                        baseImage: baseImage,
                        garmentItem: topItem,
                        category: .tshirt
                    )
                    
                    guard let intermediateImage = await loadImageFromUrl(topResult.imageUrl) else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load intermediate image"])
                    }
                    
                    // Second try-on with bottom
                    let finalResult = try await performSingleTryOn(
                        baseImage: intermediateImage,
                        garmentItem: bottomItem,
                        category: .trousers
                    )
                    
                    // Download and save the final image
                    if let url = URL(string: finalResult.imageUrl),
                       let (data, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: data) {
                        
                        let fileName = "outfit_\(outfit.id).jpg"
                        let localPath = try await wardrobeManager.saveImage(image, withName: fileName)
                        
                        // Update the outfit with the final image
                        await wardrobeManager.updateOutfit(outfit, withImageUrl: finalResult.imageUrl, localPath: localPath)
                    }
                }
            } catch {
                // Remove the outfit if it times out or fails
                await wardrobeManager.removeOutfit(outfit.id)
                print("Failed to process outfit: \(error.localizedDescription)")
            }
        }
    }
    
    private func performSingleTryOn(baseImage: UIImage, garmentItem: ClothingItem, category: ClothingCategory) async throws -> TryOnResult {
        // Get the full image path for API request
        guard let fullImagePath = wardrobeManager.getFullImagePath(for: garmentItem),
              let fullImage = UIImage(contentsOfFile: fullImagePath) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load full garment image"])
        }
        
        // Convert images to base64
        guard let modelImageBase64 = baseImage.jpegData(compressionQuality: 0.8)?.base64EncodedString(),
              let garmentImageBase64 = fullImage.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode images"])
        }
        
        // Add data URI prefix to base64 strings
        let modelBase64 = "data:image/jpeg;base64," + modelImageBase64
        let garmentBase64 = "data:image/jpeg;base64," + garmentImageBase64
        
        // Build the request
        let runUrl = URL(string: "https://api.fashn.ai/v1/run")!
        var request = URLRequest(url: runUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(FashnAPIClient.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model_image": modelBase64,
            "garment_image": garmentBase64,
            "category": category.apiValue,
            "mode": "quality",
            "restore_clothes": true,
            "cover_feet": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 3) Make the API call
        print("🚀 Sending request to Fashn API...")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TryOnResponse.self, from: data)
        
        if let error = response.error {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        
        // 4) Poll for completion
        var statusResponse: StatusResponse
        repeat {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            
            let statusUrl = URL(string: "https://api.fashn.ai/v1/status/\(response.id)")!
            var statusRequest = URLRequest(url: statusUrl)
            statusRequest.setValue("Bearer \(FashnAPIClient.apiKey)", forHTTPHeaderField: "Authorization")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            statusResponse = try JSONDecoder().decode(StatusResponse.self, from: statusData)
            
            if let error = statusResponse.error {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error.message])
            }
            
        } while statusResponse.status == "processing"
        
        guard let outputUrl = statusResponse.output?.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No output URL received"])
        }
        
        // 5) Create and return result
        return TryOnResult(
            id: response.id,
            imageUrl: outputUrl,
            category: category.rawValue,
            createdAt: Date(),
            status: .completed
        )
    }
    
    private func loadImageFromUrl(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    // Helper function to implement timeout
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

struct WardrobeItemView: View {
    let item: ClothingItem
    let isSelected: Bool
    @StateObject private var wardrobeManager = WardrobeManager.shared
    
    var body: some View {
        if let path = item.localImagePath,
           let image = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: path)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
        }
    }
} 