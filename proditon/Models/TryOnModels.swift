enum ClothingCategory: String, CaseIterable {
    case tshirt = "TShirt"
    case trousers = "Trousers"
    case dress = "Dress"
    case accessory = "Accessory"
    case shoes = "Shoes"
    
    var apiValue: String {
        switch self {
        case .tshirt: return "tops"
        case .trousers: return "bottoms"
        case .dress: return "one-pieces"
        case .accessory: return "accessories"
        case .shoes: return "shoes"
        }
    }
    
    // Helper to convert from ClothingItem.ClothingCategory
    static func from(_ wardrobeCategory: ClothingItem.ClothingCategory) -> ClothingCategory {
        switch wardrobeCategory {
        case .top: return .tshirt
        case .bottom: return .trousers
        case .dress: return .dress
        case .accessory: return .accessory
        case .shoes: return .shoes
        }
    }
}

struct TryOnRequest: Encodable {
    let modelImage: String
    let garmentImage: String
    let category: String
    let mode: String
    let restoreClothes: Bool
    
    enum CodingKeys: String, CodingKey {
        case modelImage = "model_image"
        case garmentImage = "garment_image"
        case category
        case mode
        case restoreClothes = "restore_clothes"
    }
} 