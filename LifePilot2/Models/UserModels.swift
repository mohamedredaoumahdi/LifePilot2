import Foundation

// MARK: - User Profile Model
struct UserProfile: Codable {
    var id: String
    var name: String
    var email: String
    var createdAt: Date
    var personalityType: String?
    var onboardingCompleted: Bool
    
    // User preferences and characteristics from onboarding
    var sleepPreference: SleepPreference
    var activityLevel: ActivityLevel
    var focusAreas: [FocusArea]
    var currentChallenges: [Challenge]
    
    init(id: String = UUID().uuidString,
         name: String,
         email: String,
         createdAt: Date = Date(),
         personalityType: String? = nil,
         onboardingCompleted: Bool = false,
         sleepPreference: SleepPreference = .neutral,
         activityLevel: ActivityLevel = .moderate,
         focusAreas: [FocusArea] = [],
         currentChallenges: [Challenge] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.personalityType = personalityType
        self.onboardingCompleted = onboardingCompleted
        self.sleepPreference = sleepPreference
        self.activityLevel = activityLevel
        self.focusAreas = focusAreas
        self.currentChallenges = currentChallenges
    }
}

// MARK: - Enums for User Profile
enum SleepPreference: String, Codable, CaseIterable {
    case earlyRiser = "Early Riser"
    case neutral = "Neutral"
    case nightOwl = "Night Owl"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case light = "Light"
    case moderate = "Moderate"
    case active = "Active"
    case veryActive = "Very Active"
}

enum FocusArea: String, Codable, CaseIterable {
    case health = "Health & Fitness"
    case productivity = "Productivity"
    case career = "Career Growth"
    case relationships = "Relationships"
    case learning = "Learning & Skills"
    case mindfulness = "Mindfulness & Mental Health"
    case finance = "Finance"
    case creativity = "Creativity"
    
    // Helper function to match string to enum case, with resilient matching
    static func fromString(_ string: String) -> FocusArea {
        // Try exact match first
        if let match = FocusArea(rawValue: string) {
            return match
        }
        
        // Try simplified matching (case insensitive, partial match)
        let simplified = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("health") || simplified.contains("fitness") {
            return .health
        } else if simplified.contains("product") {
            return .productivity
        } else if simplified.contains("career") || simplified.contains("work") || simplified.contains("job") {
            return .career
        } else if simplified.contains("relation") || simplified.contains("social") {
            return .relationships
        } else if simplified.contains("learn") || simplified.contains("skill") || simplified.contains("education") {
            return .learning
        } else if simplified.contains("mind") || simplified.contains("mental") || simplified.contains("stress") {
            return .mindfulness
        } else if simplified.contains("financ") || simplified.contains("money") || simplified.contains("budget") {
            return .finance
        } else if simplified.contains("creat") || simplified.contains("art") {
            return .creativity
        }
        
        // Default to health if no match found
        print("Warning: Could not match focus area '\(string)', defaulting to health")
        return .health
    }
}

enum Challenge: String, Codable, CaseIterable {
    case timeManagement = "Time Management"
    case consistency = "Consistency"
    case motivation = "Motivation"
    case energy = "Energy Levels"
    case stress = "Stress"
    case focus = "Focus & Concentration"
    case sleepQuality = "Sleep Quality"
    case workLifeBalance = "Work-Life Balance"
}

// MARK: - Goal Model
struct Goal: Codable, Identifiable {
    var id: String
    var userId: String
    var title: String
    var description: String
    var focusArea: FocusArea
    var priority: Priority
    var deadline: Date?
    var createdAt: Date
    var status: GoalStatus
    var milestones: [Milestone]?
    
    init(id: String = UUID().uuidString,
         userId: String,
         title: String,
         description: String,
         focusArea: FocusArea,
         priority: Priority = .medium,
         deadline: Date? = nil,
         createdAt: Date = Date(),
         status: GoalStatus = .active,
         milestones: [Milestone]? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.focusArea = focusArea
        self.priority = priority
        self.deadline = deadline
        self.createdAt = createdAt
        self.status = status
        self.milestones = milestones
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum GoalStatus: String, Codable, CaseIterable {
    case active = "Active"
    case completed = "Completed"
    case paused = "Paused"
    case abandoned = "Abandoned"
}

struct Milestone: Codable, Identifiable {
    var id: String
    var title: String
    var completed: Bool
    var dueDate: Date?
    
    init(id: String = UUID().uuidString,
         title: String,
         completed: Bool = false,
         dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.completed = completed
        self.dueDate = dueDate
    }
}

// MARK: - Analysis and Feedback Models
struct PersonalizedAnalysis: Codable, Identifiable {
    var id: String
    var userId: String
    var generatedAt: Date
    var insights: [Insight]
    var recommendations: [Recommendation]
    var evidenceLinks: [EvidenceLink]?
    
    init(id: String = UUID().uuidString,
         userId: String,
         generatedAt: Date,
         insights: [Insight],
         recommendations: [Recommendation],
         evidenceLinks: [EvidenceLink]? = nil) {
        self.id = id
        self.userId = userId
        self.generatedAt = generatedAt
        self.insights = insights
        self.recommendations = recommendations
        self.evidenceLinks = evidenceLinks
    }
}

struct Insight: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var focusArea: FocusArea
    var severity: InsightSeverity
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         focusArea: FocusArea,
         severity: InsightSeverity = .neutral) {
        self.id = id
        self.title = title
        self.description = description
        self.focusArea = focusArea
        self.severity = severity
    }
    
    // Custom decoder for handling API responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode standard properties
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle focusArea - try to match with existing enum
        let focusAreaString = try container.decode(String.self, forKey: .focusArea)
        focusArea = FocusArea.fromString(focusAreaString)
        
        // Handle severity - try to match with existing enum
        let severityString = try container.decode(String.self, forKey: .severity)
        severity = InsightSeverity.fromString(severityString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, focusArea, severity
    }
}

enum InsightSeverity: String, Codable, CaseIterable {
    case positive = "Positive"
    case neutral = "Neutral"
    case needsAttention = "Needs Attention"
    case critical = "Critical"
    
    // Helper function to match string to enum case, with resilient matching
    static func fromString(_ string: String) -> InsightSeverity {
        // Try exact match first
        if let match = InsightSeverity(rawValue: string) {
            return match
        }
        
        // Try simplified matching (case insensitive)
        let simplified = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("positive") || simplified.contains("good") {
            return .positive
        } else if simplified.contains("neutral") || simplified.contains("normal") {
            return .neutral
        } else if simplified.contains("attention") || simplified.contains("improve") || simplified.contains("needs") {
            return .needsAttention
        } else if simplified.contains("critical") || simplified.contains("severe") || simplified.contains("urgent") {
            return .critical
        }
        
        // Default to neutral if no match found
        print("Warning: Could not match severity '\(string)', defaulting to neutral")
        return .neutral
    }
}

struct Recommendation: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var focusArea: FocusArea
    var impact: RecommendationImpact
    var timeframe: TimeFrame
    var accepted: Bool?
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         focusArea: FocusArea,
         impact: RecommendationImpact = .medium,
         timeframe: TimeFrame = .shortTerm,
         accepted: Bool? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.focusArea = focusArea
        self.impact = impact
        self.timeframe = timeframe
        self.accepted = accepted
    }
    
    // Custom decoder for handling API responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode standard properties
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle focusArea - try to match with existing enum
        let focusAreaString = try container.decode(String.self, forKey: .focusArea)
        focusArea = FocusArea.fromString(focusAreaString)
        
        // Handle impact - try to match with existing enum
        let impactString = try container.decode(String.self, forKey: .impact)
        impact = RecommendationImpact.fromString(impactString)
        
        // Handle timeframe - try to match with existing enum
        let timeframeString = try container.decode(String.self, forKey: .timeframe)
        timeframe = TimeFrame.fromString(timeframeString)
        
        // Accepted is optional, use nil if not present
        accepted = try container.decodeIfPresent(Bool.self, forKey: .accepted)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, focusArea, impact, timeframe, accepted
    }
}

enum RecommendationImpact: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    // Helper function to match string to enum case, with resilient matching
    static func fromString(_ string: String) -> RecommendationImpact {
        // Try exact match first
        if let match = RecommendationImpact(rawValue: string) {
            return match
        }
        
        // Try simplified matching (case insensitive)
        let simplified = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("low") || simplified.contains("minimal") {
            return .low
        } else if simplified.contains("high") || simplified.contains("significant") || simplified.contains("major") {
            return .high
        } else {
            // Default to medium for anything else
            return .medium
        }
    }
}

enum TimeFrame: String, Codable, CaseIterable {
    case immediate = "Immediate"
    case shortTerm = "Short Term (Days)"
    case mediumTerm = "Medium Term (Weeks)"
    case longTerm = "Long Term (Months)"
    
    // Helper function to match string to enum case, with resilient matching
    static func fromString(_ string: String) -> TimeFrame {
        // Try exact match first
        if let match = TimeFrame(rawValue: string) {
            return match
        }
        
        // Try simplified matching (case insensitive)
        let simplified = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("immediate") || simplified.contains("now") || simplified.contains("right away") {
            return .immediate
        } else if simplified.contains("short") || simplified.contains("day") {
            return .shortTerm
        } else if simplified.contains("medium") || simplified.contains("week") {
            return .mediumTerm
        } else if simplified.contains("long") || simplified.contains("month") {
            return .longTerm
        } else {
            // Default to shortTerm for anything else
            return .shortTerm
        }
    }
}

struct EvidenceLink: Codable, Identifiable {
    var id: String
    var title: String
    var url: URL
    var type: EvidenceType
    
    init(id: String = UUID().uuidString,
         title: String,
         url: URL,
         type: EvidenceType = .article) {
        self.id = id
        self.title = title
        self.url = url
        self.type = type
    }
    
    // Custom decoder for handling API responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode standard properties
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        
        // Handle URL - might be string or URL
        let urlString = try container.decode(String.self, forKey: .url)
        
        if let parsedURL = URL(string: urlString) {
            url = parsedURL
        } else {
            // If URL is invalid, create a placeholder URL
            print("Warning: Invalid URL '\(urlString)', using placeholder URL")
            url = URL(string: "https://example.com")!
        }
        
        // Handle type - try to match with existing enum
        let typeString = try container.decode(String.self, forKey: .type)
        type = EvidenceType.fromString(typeString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, type
    }
}

enum EvidenceType: String, Codable, CaseIterable {
    case article = "Article"
    case study = "Scientific Study"
    case book = "Book"
    case video = "Video"
    case podcast = "Podcast"
    
    // Helper function to match string to enum case, with resilient matching
    static func fromString(_ string: String) -> EvidenceType {
        // Try exact match first
        if let match = EvidenceType(rawValue: string) {
            return match
        }
        
        // Try simplified matching (case insensitive)
        let simplified = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("article") || simplified.contains("blog") {
            return .article
        } else if simplified.contains("stud") || simplified.contains("research") || simplified.contains("science") {
            return .study
        } else if simplified.contains("book") {
            return .book
        } else if simplified.contains("video") {
            return .video
        } else if simplified.contains("podcast") || simplified.contains("audio") {
            return .podcast
        } else {
            // Default to article for anything else
            return .article
        }
    }
}
