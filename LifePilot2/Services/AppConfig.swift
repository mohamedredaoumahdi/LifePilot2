import Foundation

/// Configuration class that stores API keys and app settings
struct AppConfig {
    // MARK: - App Settings
    struct App {
        static let appName = "LifePilot"
        static let versionNumber = "1.0.0"
        static let appBundleIdentifier = "com.mohamedredaoumahdi.lifepilot.LifePilot2"
        
        // UserDefaults keys
        struct UserDefaults {
            static let hasCompletedOnboarding = "hasCompletedOnboarding"
            static let analysisGenerationInProgress = "analysisGenerationInProgress"
            static let analysisGenerationStartTime = "analysisGenerationStartTime"
            static let pendingAnalysisUserId = "pendingAnalysisUserId"
        }
        
        // Notification names
        struct Notifications {
            static let analysisComplete = "AnalysisComplete"
            static let userAccountDeleted = "UserAccountDeleted"
        }
    }
    
    // MARK: - API Keys
    static let cohereAPIKey = "FH6hpfFBBWqWnLuveTEc9nBOwyhh1HAHizDUGYZe"
    
    // MARK: - Cohere API Settings
    struct Cohere {
        static let baseURL = "https://api.cohere.ai/v1/generate"
        static let model = "command" // Or your preferred model
        static let maxTokens = 2000
        static let temperature = 0.7
        static let stopSequences: [String] = ["Human:", "User:"]
        
        // Retry configuration
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 2.0 // seconds
    }
    
    // MARK: - Firebase Configuration
    struct Firebase {
        // Collection names
        static let userCollectionName = "users"
        static let goalsCollectionName = "goals"
        static let scheduleCollectionName = "weeklySchedules"
        static let analysisCollectionName = "personalizedAnalysis"
        
        // Storage paths
        static let userAvatarPath = "userAvatars"
        
        // Document fields
        struct Fields {
            // User fields
            static let id = "id"
            static let name = "name"
            static let email = "email"
            static let createdAt = "createdAt"
            static let onboardingCompleted = "onboardingCompleted"
            
            // Analysis fields
            static let userId = "userId"
            static let generatedAt = "generatedAt"
            static let insights = "insights"
            static let recommendations = "recommendations"
            static let evidenceLinks = "evidenceLinks"
            
            // Schedule fields
            static let days = "days"
            static let lastModified = "lastModified"
            static let activities = "activities"
        }
    }
    
    // MARK: - UI Configuration
    struct UI {
        // Colors
        static let primaryColor = "blue"
        static let secondaryColor = "green"
        static let accentColor = "orange"
        
        // Animation durations
        static let shortAnimationDuration = 0.3
        static let mediumAnimationDuration = 0.5
        static let longAnimationDuration = 0.8
        
        // Timeouts
        static let analysisGenerationTimeout: TimeInterval = 180.0 // 3 minutes
    }
    
    // MARK: - Debug Settings
    struct Debug {
        static let enableVerboseLogging = true
        static let enableServiceMocking = false
        
        // Only print debug logs if verbose logging is enabled
        static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            if enableVerboseLogging {
                let fileName = (file as NSString).lastPathComponent
                print("📝 [\(fileName):\(line)] \(function) - \(message)")
            }
        }
        
        static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            let fileName = (file as NSString).lastPathComponent
            print("❌ [\(fileName):\(line)] \(function) - \(message)")
        }
        
        static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
            let fileName = (file as NSString).lastPathComponent
            print("✅ [\(fileName):\(line)] \(function) - \(message)")
        }
    }
}
