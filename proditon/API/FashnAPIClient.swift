import Foundation

struct FashnAPIClient {
    private static let baseURL = "https://api.fashn.ai/v1"
    public static let apiKey = "fa-aykumW0mxp28-JmI9liPjbyJExVrEH3BsCuw1" // Should be moved to a secure configuration
    
    static func createRequest(endpoint: String) -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            fatalError("Invalid URL: \(baseURL + endpoint)")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
} 