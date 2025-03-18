import Foundation
import Combine

class WeeklyScheduleViewModel: ObservableObject {
    // Published properties
    @Published var weeklySchedule: WeeklySchedule?
    @Published var selectedDay: DayOfWeek = getCurrentDayOfWeek()
    @Published var isLoading = false
    @Published var error: String?
    @Published var showingActivityForm = false
    @Published var editingActivity: ScheduledActivity?
    
    // Services
    private let databaseService: FirebaseDatabaseServiceProtocol
    private let analysisViewModel: PersonalizedAnalysisViewModel
    private let scheduleGeneratorService: ScheduleGeneratorServiceProtocol
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Initialize with dependencies
    init(databaseService: FirebaseDatabaseServiceProtocol = FirebaseDatabaseService(),
         analysisViewModel: PersonalizedAnalysisViewModel = PersonalizedAnalysisViewModel(),
         scheduleGeneratorService: ScheduleGeneratorServiceProtocol = ScheduleGeneratorService()) {
        self.databaseService = databaseService
        self.analysisViewModel = analysisViewModel
        self.scheduleGeneratorService = scheduleGeneratorService
        
        // Fetch data when initialized
        fetchSchedule()
    }
    
    // MARK: - Public Methods
    
    /// Fetch the user's weekly schedule
    func fetchSchedule() {
        guard let userId = analysisViewModel.userProfile?.id else {
            self.error = "User ID not available"
            return
        }
        
        self.isLoading = true
        self.error = nil
        
        // For now, we'll generate a schedule based on the accepted recommendations
        // In a real app, you would fetch this from Firebase
        analysisViewModel.fetchExistingAnalysis()
        
        // Wait for analysis to be fetched
        analysisViewModel.$analysis
            .compactMap { $0 }
            .first()
            .sink { [weak self] analysis in
                guard let self = self else { return }
                
                // Get accepted recommendations
                let acceptedRecommendations = analysis.recommendations.filter { $0.accepted == true }
                
                // Generate schedule
                let schedule = self.scheduleGeneratorService.generateWeeklySchedule(
                    userId: userId,
                    recommendations: acceptedRecommendations
                )
                
                // Update state
                DispatchQueue.main.async {
                    self.weeklySchedule = schedule
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
    
    /// Add a new activity to the schedule
    func addActivity(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day to add the activity to
        let dayOfWeek = getDayOfWeek(from: activity.startTime)
        
        if let dayIndex = weeklySchedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            // Add the activity
            weeklySchedule.days[dayIndex].activities.append(activity)
            
            // Sort activities by start time
            weeklySchedule.days[dayIndex].activities.sort { a, b in
                return a.startTime < b.startTime
            }
            
            // Update the schedule
            self.weeklySchedule = weeklySchedule
            
            // Update the last modified date
            weeklySchedule.lastModified = Date()
            
            // Save to Firebase (not implemented in this MVP)
            saveSchedule()
        }
    }
    
    /// Update an existing activity
    func updateActivity(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day that contains the activity
        let dayOfWeek = getDayOfWeek(from: activity.startTime)
        
        if let dayIndex = weeklySchedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            // Find the activity to update
            if let activityIndex = weeklySchedule.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) {
                // Update the activity
                weeklySchedule.days[dayIndex].activities[activityIndex] = activity
                
                // Sort activities by start time
                weeklySchedule.days[dayIndex].activities.sort { a, b in
                    return a.startTime < b.startTime
                }
                
                // Update the schedule
                self.weeklySchedule = weeklySchedule
                
                // Update the last modified date
                weeklySchedule.lastModified = Date()
                
                // Save to Firebase (not implemented in this MVP)
                saveSchedule()
            }
        }
    }
    
    /// Delete an activity
    func deleteActivity(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day that contains the activity
        for dayIndex in 0..<weeklySchedule.days.count {
            // Find the activity to delete
            if let activityIndex = weeklySchedule.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) {
                // Remove the activity
                weeklySchedule.days[dayIndex].activities.remove(at: activityIndex)
                
                // Update the schedule
                self.weeklySchedule = weeklySchedule
                
                // Update the last modified date
                weeklySchedule.lastModified = Date()
                
                // Save to Firebase (not implemented in this MVP)
                saveSchedule()
                
                break
            }
        }
    }
    
    /// Mark an activity as completed or incomplete
    func toggleActivityCompletion(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day that contains the activity
        for dayIndex in 0..<weeklySchedule.days.count {
            // Find the activity to update
            if let activityIndex = weeklySchedule.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) {
                // Toggle the completion status
                weeklySchedule.days[dayIndex].activities[activityIndex].isCompleted.toggle()
                
                // Update the schedule
                self.weeklySchedule = weeklySchedule
                
                // Update the last modified date
                weeklySchedule.lastModified = Date()
                
                // Save to Firebase (not implemented in this MVP)
                saveSchedule()
                
                break
            }
        }
    }
    
    /// Generate a new schedule based on accepted recommendations
    func regenerateSchedule() {
        guard let userId = analysisViewModel.userProfile?.id,
              let analysis = analysisViewModel.analysis else {
            self.error = "User profile or analysis not available"
            return
        }
        
        self.isLoading = true
        self.error = nil
        
        // Get accepted recommendations
        let acceptedRecommendations = analysis.recommendations.filter { $0.accepted == true }
        
        // Generate new schedule
        let newSchedule = scheduleGeneratorService.generateWeeklySchedule(
            userId: userId,
            recommendations: acceptedRecommendations
        )
        
        // Update state
        DispatchQueue.main.async {
            self.weeklySchedule = newSchedule
            self.isLoading = false
            
            // Save to Firebase (not implemented in this MVP)
            self.saveSchedule()
        }
    }
    
    // MARK: - Private Methods
    
    /// Save the schedule to Firebase
    private func saveSchedule() {
        guard let schedule = weeklySchedule else { return }
        
        // In a real app, you would save this to Firebase
        // For this MVP, we'll just print a message
        print("Saving schedule to Firebase (not implemented)")
    }
    
    /// Get the current day of the week
    private static func getCurrentDayOfWeek() -> DayOfWeek {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
    
    /// Get the day of the week from a date
    private func getDayOfWeek(from date: Date) -> DayOfWeek {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
    
    /// Get activities for the selected day
    func activitiesForSelectedDay() -> [ScheduledActivity] {
        guard let weeklySchedule = weeklySchedule,
              let day = weeklySchedule.days.first(where: { $0.dayOfWeek == selectedDay }) else {
            return []
        }
        
        return day.activities
    }
    
    /// Format time to display in the UI
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
