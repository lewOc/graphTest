import Foundation

struct Outfit: Identifiable, Codable {
    let id: String
    let topItemId: String
    let bottomItemId: String
    let imageUrl: String
    let localImagePath: String?
    let createdAt: Date
    var isProcessing: Bool = false
    var accessories: [AccessoryPlacement] = []
} 