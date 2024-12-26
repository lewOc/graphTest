import Foundation
import SwiftUI

@MainActor
class WardrobeManager: ObservableObject {
    static let shared = WardrobeManager()
    
    @Published private(set) var items: [ClothingItem] = []
    @Published private(set) var outfits: [Outfit] = []
    
    private let userDefaults = UserDefaults.standard
    private let itemsKey = "wardrobeItems"
    private let outfitsKey = "wardrobeOutfits"
    private let fileManager = FileManager.default
    
    private var wardrobeDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wardrobeDirectory = documentsDirectory.appendingPathComponent("Wardrobe", isDirectory: true)
        
        if !fileManager.fileExists(atPath: wardrobeDirectory.path) {
            try? fileManager.createDirectory(at: wardrobeDirectory, withIntermediateDirectories: true)
        }
        
        return wardrobeDirectory
    }
    
    private init() {
        createWardrobeDirectoryIfNeeded()
        loadItems()
        loadOutfits()
    }
    
    private func createWardrobeDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: wardrobeDirectory.path) {
            try? fileManager.createDirectory(at: wardrobeDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func loadItems() {
        if let data = userDefaults.data(forKey: itemsKey),
           let decodedItems = try? JSONDecoder().decode([ClothingItem].self, from: data) {
            items = decodedItems.filter { item in
                guard let relativePath = item.localImagePath else { return false }
                let absolutePath = getAbsolutePath(for: relativePath)
                return fileManager.fileExists(atPath: absolutePath)
            }
            
            if items.count != decodedItems.count {
                saveItems()
            }
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            userDefaults.set(encoded, forKey: itemsKey)
            userDefaults.synchronize()
        }
    }
    
    func addItem(image: UIImage, originalImage: UIImage, category: ClothingItem.ClothingCategory) async throws -> ClothingItem {
        let maskedFileName = "masked_\(UUID().uuidString).png"
        let fullFileName = "full_\(UUID().uuidString).jpg"
        
        // Save both images
        let maskedPath = try await saveImage(image, withName: maskedFileName)
        let fullPath = try await saveImage(originalImage, withName: fullFileName)
        
        let item = ClothingItem(
            id: UUID().uuidString,
            category: category,
            imageUrl: "", // This will be populated when used with API
            localImagePath: maskedPath,
            fullImagePath: fullPath,
            createdAt: Date()
        )
        
        items.append(item)
        saveItems()
        
        return item
    }
    
    public func saveImage(_ image: UIImage, withName fileName: String) async throws -> String {
        guard let data = image.pngData() else {
            throw NSError(domain: "WardrobeManager", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileURL = wardrobeDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        
        return "Wardrobe/" + fileName
    }
    
    public func getAbsolutePath(for relativePath: String) -> String {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(relativePath)
            .path
    }
    
    func deleteItem(_ item: ClothingItem) {
        // Delete masked image
        if let relativePath = item.localImagePath {
            let absolutePath = getAbsolutePath(for: relativePath)
            try? fileManager.removeItem(atPath: absolutePath)
        }
        
        // Delete full image
        if let relativePath = item.fullImagePath {
            let absolutePath = getAbsolutePath(for: relativePath)
            try? fileManager.removeItem(atPath: absolutePath)
        }
        
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    private func loadOutfits() {
        if let data = userDefaults.data(forKey: outfitsKey),
           let decodedOutfits = try? JSONDecoder().decode([Outfit].self, from: data) {
            outfits = decodedOutfits.filter { outfit in
                guard let relativePath = outfit.localImagePath else { return false }
                let absolutePath = getAbsolutePath(for: relativePath)
                return fileManager.fileExists(atPath: absolutePath)
            }
        }
    }
    
    private func saveOutfits() {
        if let encoded = try? JSONEncoder().encode(outfits) {
            userDefaults.set(encoded, forKey: outfitsKey)
            userDefaults.synchronize()
        }
    }
    
    func addOutfit(imageUrl: String, topItem: ClothingItem, bottomItem: ClothingItem) async throws -> Outfit {
        guard let url = URL(string: imageUrl),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            throw NSError(domain: "WardrobeManager", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to download outfit image"])
        }
        
        let fileName = "outfit_\(UUID().uuidString).jpg"
        let localPath = try await saveImage(image, withName: fileName)
        
        let outfit = Outfit(
            id: UUID().uuidString,
            topItemId: topItem.id,
            bottomItemId: bottomItem.id,
            imageUrl: imageUrl,
            localImagePath: localPath,
            createdAt: Date()
        )
        
        outfits.append(outfit)
        saveOutfits()
        
        return outfit
    }
    
    @MainActor
    func addOutfitInProgress(topItem: ClothingItem, bottomItem: ClothingItem) -> Outfit {
        let outfit = Outfit(
            id: UUID().uuidString,
            topItemId: topItem.id,
            bottomItemId: bottomItem.id,
            imageUrl: "",
            localImagePath: nil,
            createdAt: Date(),
            isProcessing: true
        )
        
        outfits.append(outfit)
        saveOutfits()
        return outfit
    }
    
    func updateOutfit(_ outfit: Outfit, withImageUrl imageUrl: String, localPath: String) {
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            // Preserve accessories when updating outfit
            let existingAccessories = outfits[index].accessories
            outfits[index] = Outfit(
                id: outfit.id,
                topItemId: outfit.topItemId,
                bottomItemId: outfit.bottomItemId,
                imageUrl: imageUrl,
                localImagePath: localPath,
                createdAt: outfit.createdAt,
                isProcessing: false,
                accessories: existingAccessories  // Preserve existing accessories
            )
            saveOutfits()
        }
    }
    
    @MainActor
    func removeOutfit(_ outfitId: String) {
        if let outfit = outfits.first(where: { $0.id == outfitId }),
           let relativePath = outfit.localImagePath {
            let absolutePath = getAbsolutePath(for: relativePath)
            try? fileManager.removeItem(atPath: absolutePath)
        }
        outfits.removeAll { $0.id == outfitId }
        saveOutfits()
    }
    
    // Helper method to get the full image path for API requests
    func getFullImagePath(for item: ClothingItem) -> String? {
        guard let relativePath = item.fullImagePath else { return nil }
        return getAbsolutePath(for: relativePath)
    }
    
    @MainActor
    func updateOutfitAccessories(outfitId: String, accessories: [AccessoryPlacement]) async {
        if let index = outfits.firstIndex(where: { $0.id == outfitId }) {
            var updatedOutfit = outfits[index]
            updatedOutfit.accessories = accessories
            outfits[index] = updatedOutfit
            saveOutfits()
            
            // Debug logging
            print("Updated outfit accessories:")
            print("Outfit ID: \(outfitId)")
            print("Accessories count: \(accessories.count)")
            print("Positions: \(accessories.map { $0.position })")
        }
    }
} 