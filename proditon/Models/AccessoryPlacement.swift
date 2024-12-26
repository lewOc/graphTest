import Foundation

struct AccessoryPlacement: Identifiable, Codable {
    let id: String
    let itemId: String
    var position: CGPoint
    var scale: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemId
        case position
        case scale
    }
    
    // Custom coding for CGPoint
    init(id: String = UUID().uuidString, itemId: String, position: CGPoint, scale: CGFloat = 1.0) {
        self.id = id
        self.itemId = itemId
        self.position = position
        self.scale = scale
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        itemId = try container.decode(String.self, forKey: .itemId)
        let x = try container.decode(CGFloat.self, forKey: .position)
        let y = try container.decode(CGFloat.self, forKey: .position)
        position = CGPoint(x: x, y: y)
        scale = try container.decode(CGFloat.self, forKey: .scale)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemId, forKey: .itemId)
        try container.encode(position.x, forKey: .position)
        try container.encode(position.y, forKey: .position)
        try container.encode(scale, forKey: .scale)
    }
} 