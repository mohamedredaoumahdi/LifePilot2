import Foundation

/// Configuration class that stores API keys and app settings
struct AppConfig {
    // MARK: - API Keys
    static let cohereAPIKey = "FH6hpfFBBWqWnLuveTEc9nBOwyhh1HAHizDUGYZe"
    
    // MARK: - Cohere API Settings
    struct Cohere {
        static let baseURL = "https://api.cohere.ai/v1/generate"
        static let model = "command" // You can change to your preferred model
        static let maxTokens = 2000
        static let temperature = 0.7
        static let stopSequences: [String] = ["Human:", "User:"]
    }
    
    // MARK: - Firebase Configuration (Placeholders)
    struct Firebase {
        // Add your Firebase configuration here once you have your project set up
        static let userCollectionName = "users"
        static let goalsCollectionName = "goals"
        static let scheduleCollectionName = "schedules"
    }
    
    // MARK: - App Settings
    struct App {
        static let appName = "LifePilot"
        static let versionNumber = "1.0.0"
    }
}
