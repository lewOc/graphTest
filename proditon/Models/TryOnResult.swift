import Foundation

struct TryOnResult: Identifiable, Codable, Hashable {
    let id: String
    let imageUrl: String
    let category: String
    let createdAt: Date
    var status: ProcessingStatus
    var localImagePath: String?
    
    enum ProcessingStatus: String, Codable {
        case processing
        case completed
        case failed
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case category
        case createdAt = "created_at"
        case status
        case localImagePath = "local_image_path"
    }
    
    // Implement Hashable manually to ensure consistent hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable (required by Hashable) based on id
    static func == (lhs: TryOnResult, rhs: TryOnResult) -> Bool {
        lhs.id == rhs.id
    }
} 