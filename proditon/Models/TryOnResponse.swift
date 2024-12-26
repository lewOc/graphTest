import Foundation

struct TryOnResponse: Codable {
    let id: String
    let error: APIError?
}

struct StatusResponse: Codable {
    let id: String
    let status: String
    let output: [String]?
    let error: APIError?
}

struct APIError: Codable {
    let name: String
    let message: String
} 