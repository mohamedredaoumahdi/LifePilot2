import Foundation

// MARK: - Weekly Schedule Model
struct WeeklySchedule: Codable, Identifiable {
    var id: String
    var userId: String
    var createdAt: Date
    var lastModified: Date
    var days: [DaySchedule]
    
    init(id: String = UUID().uuidString,
         userId: String,
         createdAt: Date = Date(),
         lastModified: Date = Date(),
         days: [DaySchedule] = []) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.lastModified = lastModified
        
        // Initialize days if empty
        if days.isEmpty {
            var initialDays = [DaySchedule]()
            for dayOfWeek in DayOfWeek.allCases {
                initialDays.append(DaySchedule(dayOfWeek: dayOfWeek))
            }
            self.days = initialDays
        } else {
            self.days = days
        }
    }
}

// MARK: - Day Schedule Model
struct DaySchedule: Codable, Identifiable {
    var id: String
    var dayOfWeek: DayOfWeek
    var activities: [ScheduledActivity]
    
    init(id: String = UUID().uuidString,
         dayOfWeek: DayOfWeek,
         activities: [ScheduledActivity] = []) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.activities = activities
    }
}

// MARK: - Day of Week Enum
enum DayOfWeek: String, Codable, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

// MARK: - Scheduled Activity Model
struct ScheduledActivity: Codable, Identifiable {
    var id: String
    var title: String
    var description: String?
    var startTime: Date
    var endTime: Date
    var activityType: ActivityType
    var isCompleted: Bool
    var isRecommended: Bool
    var relatedRecommendationId: String?
    var color: ActivityColor
    var notes: String?
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String? = nil,
         startTime: Date,
         endTime: Date,
         activityType: ActivityType = .task,
         isCompleted: Bool = false,
         isRecommended: Bool = false,
         relatedRecommendationId: String? = nil,
         color: ActivityColor = .blue,
         notes: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.activityType = activityType
        self.isCompleted = isCompleted
        self.isRecommended = isRecommended
        self.relatedRecommendationId = relatedRecommendationId
        self.color = color
        self.notes = notes
    }
}

// MARK: - Activity Type
enum ActivityType: String, Codable, CaseIterable {
    case task = "Task"
    case habit = "Habit"
    case exercise = "Exercise"
    case meal = "Meal"
    case work = "Work"
    case leisure = "Leisure"
    case learning = "Learning"
    case mindfulness = "Mindfulness"
    case sleep = "Sleep"
}

// MARK: - Activity Color
enum ActivityColor: String, Codable, CaseIterable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"
    case red = "Red"
    case yellow = "Yellow"
    case teal = "Teal"
    case pink = "Pink"
    
    var colorValue: String {
        switch self {
        case .blue: return "#007AFF"
        case .green: return "#34C759"
        case .orange: return "#FF9500"
        case .purple: return "#AF52DE"
        case .red: return "#FF3B30"
        case .yellow: return "#FFCC00"
        case .teal: return "#5AC8FA"
        case .pink: return "#FF2D55"
        }
    }
}

// MARK: - Time Range Helper
struct TimeRange: Codable, Comparable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    
    var startTimeString: String {
        return String(format: "%02d:%02d", startHour, startMinute)
    }
    
    var endTimeString: String {
        return String(format: "%02d:%02d", endHour, endMinute)
    }
    
    var durationInMinutes: Int {
        return (endHour * 60 + endMinute) - (startHour * 60 + startMinute)
    }
    
    static func < (lhs: TimeRange, rhs: TimeRange) -> Bool {
        if lhs.startHour != rhs.startHour {
            return lhs.startHour < rhs.startHour
        }
        return lhs.startMinute < rhs.startMinute
    }
}

// MARK: - Schedule Generator Service
protocol ScheduleGeneratorServiceProtocol {
    func generateWeeklySchedule(userId: String, recommendations: [Recommendation]) -> WeeklySchedule
}

class ScheduleGeneratorService: ScheduleGeneratorServiceProtocol {
    func generateWeeklySchedule(userId: String, recommendations: [Recommendation]) -> WeeklySchedule {
        // Create a new weekly schedule
        var schedule = WeeklySchedule(userId: userId)
        
        // For each accepted recommendation, create activities in the schedule
        for recommendation in recommendations.filter({ $0.accepted == true }) {
            // Determine which days to add the activity based on the recommendation
            let daysToSchedule = determineDaysForActivity(recommendation: recommendation)
            
            // For each day, create and add the activity
            for dayOfWeek in daysToSchedule {
                if let dayIndex = schedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
                    // Create a new activity from the recommendation
                    let activity = createActivityFromRecommendation(recommendation: recommendation, dayOfWeek: dayOfWeek)
                    
                    // Add it to the schedule
                    schedule.days[dayIndex].activities.append(activity)
                }
            }
        }
        
        // Sort activities by start time for each day
        for i in 0..<schedule.days.count {
            schedule.days[i].activities.sort { a, b in
                return a.startTime < b.startTime
            }
        }
        
        return schedule
    }
    
    // Helper method to determine which days of the week to schedule an activity
    private func determineDaysForActivity(recommendation: Recommendation) -> [DayOfWeek] {
        // This is a simplified implementation
        // In a real app, you'd use more sophisticated logic based on the recommendation
        
        switch recommendation.focusArea {
        case .health, .mindfulness:
            // Health and mindfulness activities might be scheduled daily
            return [.monday, .wednesday, .friday]
            
        case .productivity, .career:
            // Work-related activities might be scheduled on weekdays
            return [.monday, .tuesday, .wednesday, .thursday, .friday]
            
        case .learning:
            // Learning might be a few times a week
            return [.tuesday, .thursday, .saturday]
            
        case .relationships:
            // Social activities might be on weekends
            return [.friday, .saturday]
            
        case .creativity:
            // Creative activities might be spaced out
            return [.wednesday, .sunday]
            
        case .finance:
            // Financial review might be once a week
            return [.sunday]
        }
    }
    
    // Helper method to create an activity from a recommendation
    private func createActivityFromRecommendation(recommendation: Recommendation, dayOfWeek: DayOfWeek) -> ScheduledActivity {
        // This is a simplified implementation
        // In a real app, you'd determine times based on the user's preferences and existing schedule
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        
        // Set the day of the week
        switch dayOfWeek {
        case .monday: dateComponents.weekday = 2
        case .tuesday: dateComponents.weekday = 3
        case .wednesday: dateComponents.weekday = 4
        case .thursday: dateComponents.weekday = 5
        case .friday: dateComponents.weekday = 6
        case .saturday: dateComponents.weekday = 7
        case .sunday: dateComponents.weekday = 1
        }
        
        // Determine start and end times based on activity type
        var startHour = 8 // Default start time
        var durationMinutes = 30 // Default duration
        var activityType: ActivityType = .task
        var activityColor: ActivityColor = .blue
        
        switch recommendation.focusArea {
        case .health:
            startHour = 7 // Early morning for health activities
            durationMinutes = 45
            activityType = .exercise
            activityColor = .green
            
        case .mindfulness:
            startHour = 6 // Early morning for mindfulness
            durationMinutes = 15
            activityType = .mindfulness
            activityColor = .purple
            
        case .productivity, .career:
            startHour = 10 // Mid-morning for work
            durationMinutes = 60
            activityType = .work
            activityColor = .blue
            
        case .learning:
            startHour = 18 // Evening for learning
            durationMinutes = 45
            activityType = .learning
            activityColor = .orange
            
        case .relationships:
            startHour = 19 // Evening for social
            durationMinutes = 120
            activityType = .leisure
            activityColor = .pink
            
        case .creativity:
            startHour = 16 // Afternoon for creativity
            durationMinutes = 60
            activityType = .leisure
            activityColor = .yellow
            
        case .finance:
            startHour = 14 // Afternoon for finance
            durationMinutes = 30
            activityType = .task
            activityColor = .teal
        }
        
        // Set the start time
        dateComponents.hour = startHour
        dateComponents.minute = 0
        let startDate = calendar.nextDate(after: Date(),
                                         matching: dateComponents,
                                         matchingPolicy: .nextTime) ?? Date()
        
        // Calculate end time
        let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? Date()
        
        // Create the activity
        return ScheduledActivity(
            title: recommendation.title,
            description: recommendation.description,
            startTime: startDate,
            endTime: endDate,
            activityType: activityType,
            isRecommended: true,
            relatedRecommendationId: recommendation.id,
            color: activityColor
        )
    }
}
