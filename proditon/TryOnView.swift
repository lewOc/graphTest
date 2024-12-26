import SwiftUI
import PhotosUI

struct TryOnView: View {
    @EnvironmentObject private var resultsManager: ResultsManager
    @State private var modelImage: UIImage?
    @State private var garmentImage: UIImage?
    @State private var modelImageSelection: PhotosPickerItem?
    @State private var garmentImageSelection: PhotosPickerItem?
    @State private var selectedCategory: ClothingCategory = .tshirt
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var loadingMessage = "Processing your virtual try-on..."
    @State private var showProcessingMessage = false
    
    private let imageSize: CGSize = CGSize(width: 150, height: 200)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Image Selection Area
                HStack(spacing: 16) {
                    // Model Image
                    VStack {
                        Text("Model Photo")
                            .font(.headline)
                        
                        PhotosPicker(selection: $modelImageSelection,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            if let image = modelImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                    }
                    
                    // Garment Image
                    VStack {
                        Text("Garment Photo")
                            .font(.headline)
                        
                        PhotosPicker(selection: $garmentImageSelection,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            if let image = garmentImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .overlay {
                                        Image(systemName: "tshirt.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Category Selection
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ClothingCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button("Reset", role: .destructive) {
                        resetForm()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Try It On") {
                        Task {
                            await performTryOn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(modelImage == nil || garmentImage == nil || isLoading)
                }
                .padding()
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Try On")
            .onChange(of: modelImageSelection) { newValue in
                if let item = newValue {
                    loadImage(from: item) { image in
                        modelImage = image
                    }
                }
            }
            .onChange(of: garmentImageSelection) { newValue in
                if let item = newValue {
                    loadImage(from: item) { image in
                        garmentImage = image
                    }
                }
            }
            .overlay {
                if isLoading {
                    LoadingView(message: loadingMessage)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    resetForm()
                }
            } message: {
                Text("Your try-on has been saved! View it in the Results tab.")
            }
            .alert("Processing", isPresented: $showProcessingMessage) {
                Button("OK, I'll check the Results tab!") {
                    showProcessingMessage = false
                }
            } message: {
                Text("Your try-on request is being processed. Head to the Results tab to see it appear!")
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem, completion: @escaping (UIImage?) -> Void) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run { completion(nil) }
                    return
                }
                await MainActor.run { completion(image) }
            } catch {
                print("Error loading image: \(error)")
                await MainActor.run { completion(nil) }
            }
        }
    }
    
    private func resetForm() {
        modelImage = nil
        garmentImage = nil
        modelImageSelection = nil
        garmentImageSelection = nil
        selectedCategory = .tshirt
        isLoading = false
        errorMessage = nil
        loadingMessage = "Processing your virtual try-on..."
    }
    
    private func performTryOn() async {
        guard let modelImage = modelImage,
              let garmentImage = garmentImage,
              let modelImageData = modelImage.jpegData(compressionQuality: 0.8),
              let garmentImageData = garmentImage.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        isLoading = true
        
        do {
            let modelBase64 = "data:image/jpeg;base64," + modelImageData.base64EncodedString()
            let garmentBase64 = "data:image/jpeg;base64," + garmentImageData.base64EncodedString()
            
            // Create initial request
            let tryOnResponse = try await sendInitialRequest(modelBase64: modelBase64, garmentBase64: garmentBase64)
            
            if let error = tryOnResponse.error {
                print("❌ API Error: \(error.name) - \(error.message)")
                await MainActor.run { showError(error.message) }
                return
            }
            
            print("✅ Got prediction ID: \(tryOnResponse.id)")
            
            // Add pending result immediately
            await MainActor.run {
                resultsManager.addPendingResult(id: tryOnResponse.id, category: selectedCategory.rawValue)
                showProcessingMessage = true
                isLoading = false
                resetForm()
            }
            
            // Start polling in a background task
            Task.detached {
                await self.pollForResults(predictionId: tryOnResponse.id)
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            await MainActor.run { 
                showError(error.localizedDescription)
                isLoading = false 
            }
        }
    }
    
    private func pollForResults(predictionId: String) async {
        print("🔄 Starting to poll for results: \(predictionId)")
        let statusUrl = URL(string: "https://api.fashn.ai/v1/status/\(predictionId)")!
        var request = URLRequest(url: statusUrl)
        request.setValue("Bearer fa-aykumW0mxp28-JmI9liPjbyJExVrEH3BsCuw1", forHTTPHeaderField: "Authorization")
        
        let timeout = Date().addingTimeInterval(300)
        
        while Date() < timeout {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let status = try JSONDecoder().decode(StatusResponse.self, from: data)
                print("📊 Status update for \(predictionId): \(status.status)")
                
                switch status.status {
                case "completed":
                    if let outputUrl = status.output?.first {
                        print("✨ Got completed image URL: \(outputUrl)")
                        await resultsManager.updateResult(id: predictionId, imageUrl: outputUrl)
                        return
                    }
                    
                case "failed":
                    if let error = status.error {
                        print("❌ Generation failed: \(error.message)")
                        await MainActor.run {
                            resultsManager.markResultFailed(id: predictionId)
                            showError("Generation failed: \(error.message)")
                        }
                    }
                    return
                    
                case "canceled":
                    print("🚫 Request was canceled")
                    await MainActor.run {
                        resultsManager.markResultFailed(id: predictionId)
                        showError("The request was canceled.")
                    }
                    return
                    
                default:
                    print("⏳ Still processing...")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch {
                print("❌ Error checking status: \(error.localizedDescription)")
                await MainActor.run {
                    resultsManager.markResultFailed(id: predictionId)
                    showError("Error checking status: \(error.localizedDescription)")
                }
                return
            }
        }
        
        print("⏰ Request timed out")
        await MainActor.run { 
            resultsManager.markResultFailed(id: predictionId)
            showError("The request timed out after 5 minutes")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    @MainActor
    private func handleAPIResponse(_ imageUrl: String) async {
        print("Adding result to manager: \(imageUrl), category: \(selectedCategory.rawValue)")
        await resultsManager.addResult(
            imageUrl: imageUrl,
            category: selectedCategory.rawValue
        )
        print("Current results count: \(resultsManager.results.count)")
    }
    
    private func sendInitialRequest(modelBase64: String, garmentBase64: String) async throws -> TryOnResponse {
        var request = URLRequest(url: URL(string: "https://api.fashn.ai/v1/run")!)
        request.httpMethod = "POST"
        request.setValue("Bearer fa-aykumW0mxp28-JmI9liPjbyJExVrEH3BsCuw1", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model_image": modelBase64,
            "garment_image": garmentBase64,
            "category": selectedCategory.apiValue,
            "mode": "quality",
            "restore_clothes": true,
            "cover_feet": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🚀 Sending request to Fashn API...")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TryOnResponse.self, from: data)
        print("📥 Received response: \(String(data: data, encoding: .utf8) ?? "no data")")
        
        return response
    }
}

#Preview {
    TryOnView()
} 