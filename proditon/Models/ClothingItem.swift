import Foundation

struct ClothingItem: Identifiable, Codable, Hashable {
    let id: String
    let category: ClothingCategory
    let imageUrl: String
    let localImagePath: String?  // masked image path
    let fullImagePath: String?   // full original image path
    let createdAt: Date
    
    enum ClothingCategory: String, Codable, CaseIterable {
        case top = "Top"
        case bottom = "Bottom"
        case dress = "Dress"
        case accessory = "Accessory"
        case shoes = "Shoes"
    }
    
    // Implement Hashable manually to ensure consistent hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable (required by Hashable) based on id
    static func == (lhs: ClothingItem, rhs: ClothingItem) -> Bool {
        lhs.id == rhs.id
    }
} 