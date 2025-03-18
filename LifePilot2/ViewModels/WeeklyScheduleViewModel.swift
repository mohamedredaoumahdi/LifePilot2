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
    private var scheduleSubscription: AnyCancellable?
    private var userId: String?
    
    // Initialize with dependencies
    init(databaseService: FirebaseDatabaseServiceProtocol = FirebaseDatabaseService(),
         analysisViewModel: PersonalizedAnalysisViewModel = PersonalizedAnalysisViewModel(),
         scheduleGeneratorService: ScheduleGeneratorServiceProtocol = ScheduleGeneratorService()) {
        self.databaseService = databaseService
        self.analysisViewModel = analysisViewModel
        self.scheduleGeneratorService = scheduleGeneratorService
        
        // Subscribe to user profile changes
        setupUserSubscription()
    }
    
    deinit {
        scheduleSubscription?.cancel()
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Setup and Configuration
    
    private func setupUserSubscription() {
        // Subscribe to user profile changes from the analysis view model
        analysisViewModel.$userProfile
            .compactMap { $0 }
            .sink { [weak self] userProfile in
                let userId = userProfile.id
                if self?.userId != userId {
                    self?.userId = userId
                    AppConfig.Debug.log("WeeklyScheduleViewModel received user ID: \(userId)")
                    self?.setupScheduleListener(userId: userId)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to accepted recommendations changes
        analysisViewModel.$analysis
            .compactMap { $0 }
            .sink { [weak self] analysis in
                AppConfig.Debug.log("WeeklyScheduleViewModel received updated analysis with \(analysis.recommendations.count) recommendations")
                // If we don't have a schedule yet but have recommendations, generate one
                if self?.weeklySchedule == nil && !analysis.recommendations.isEmpty {
                    self?.regenerateSchedule()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupScheduleListener(userId: String) {
        // Cancel any existing subscription
        scheduleSubscription?.cancel()
        
        // Set up a new subscription
        scheduleSubscription = databaseService.observeSchedule(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Error observing schedule: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error observing schedule: \(error)")
                    }
                },
                receiveValue: { [weak self] schedule in
                    self?.weeklySchedule = schedule
                    if schedule != nil {
                        AppConfig.Debug.success("Real-time schedule update received")
                        // Clear the loading state and error if we receive a schedule
                        self?.isLoading = false
                        self?.error = nil
                    } else if self?.weeklySchedule == nil {
                        // No schedule exists yet, try to generate one
                        AppConfig.Debug.log("No schedule found, attempting to generate one")
                        self?.regenerateSchedule()
                    }
                }
            )
    }
    
    // MARK: - Public Methods
    
    /// Set user ID explicitly (used when passing from view)
    func setUserId(_ id: String) {
        AppConfig.Debug.log("Setting user ID in WeeklyScheduleViewModel: \(id)")
        self.userId = id
        
        // Setup listener and fetch schedule
        setupScheduleListener(userId: id)
    }
    
    /// Fetch the user's weekly schedule (one-time fetch)
    func fetchSchedule() {
        guard let userId = userId else {
            self.error = "User ID not available"
            return
        }
        
        self.isLoading = true
        self.error = nil
        
        databaseService.getSchedule(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = "Error fetching schedule: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error fetching schedule: \(error)")
                    }
                },
                receiveValue: { [weak self] schedule in
                    if let schedule = schedule {
                        AppConfig.Debug.success("Successfully fetched schedule with \(schedule.days.count) days")
                        self?.weeklySchedule = schedule
                    } else {
                        AppConfig.Debug.log("No schedule found, will try to generate one")
                        self?.regenerateSchedule()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Add a new activity to the schedule
    func addActivity(_ activity: ScheduledActivity) {
        guard let userId = userId else {
            self.error = "User ID not available"
            return
        }
        
        if var weeklySchedule = weeklySchedule {
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
                
                // Save to Firebase
                saveSchedule(weeklySchedule)
            }
        } else {
            // No schedule exists yet, create a new one
            var newSchedule = WeeklySchedule(userId: userId)
            
            // Find the day to add the activity to
            let dayOfWeek = getDayOfWeek(from: activity.startTime)
            
            if let dayIndex = newSchedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
                // Add the activity
                newSchedule.days[dayIndex].activities.append(activity)
                
                // Update the schedule
                self.weeklySchedule = newSchedule
                
                // Save to Firebase
                saveSchedule(newSchedule)
            }
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
                
                // Save to Firebase
                saveSchedule(weeklySchedule)
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
                
                // Save to Firebase
                saveSchedule(weeklySchedule)
                
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
                
                // Save to Firebase
                saveSchedule(weeklySchedule)
                
                break
            }
        }
    }
    
    /// Generate a new schedule based on accepted recommendations
    func regenerateSchedule() {
        guard let userId = userId else {
            self.error = "User ID not available"
            return
        }
        
        self.isLoading = true
        self.error = nil
        
        // Get accepted recommendations from the analysis view model
        analysisViewModel.fetchExistingAnalysis()
        
        // Wait for analysis to be fetched
        analysisViewModel.$analysis
            .compactMap { $0 }
            .first()
            .sink { [weak self] analysis in
                guard let self = self else { return }
                
                // Get accepted recommendations
                let acceptedRecommendations = analysis.recommendations.filter { $0.accepted == true }
                
                if acceptedRecommendations.isEmpty {
                    AppConfig.Debug.log("No accepted recommendations found, generating empty schedule")
                    let emptySchedule = WeeklySchedule(userId: userId)
                    self.weeklySchedule = emptySchedule
                    self.isLoading = false
                    self.saveSchedule(emptySchedule)
                    return
                }
                
                // Generate new schedule
                let newSchedule = self.scheduleGeneratorService.generateWeeklySchedule(
                    userId: userId,
                    recommendations: acceptedRecommendations
                )
                
                // Update state
                DispatchQueue.main.async {
                    self.weeklySchedule = newSchedule
                    self.isLoading = false
                    
                    // Save to Firebase
                    self.saveSchedule(newSchedule)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    /// Save the schedule to Firebase
    private func saveSchedule(_ schedule: WeeklySchedule) {
        AppConfig.Debug.log("Saving schedule to Firebase for userId: \(schedule.userId)")
        
        databaseService.saveSchedule(schedule)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Error saving schedule: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error saving schedule: \(error)")
                    } else {
                        AppConfig.Debug.success("Schedule saved successfully to Firebase")
                    }
                },
                receiveValue: { _ in
                    // Successfully saved
                }
            )
            .store(in: &cancellables)
    }
    
    /// Get the current day of the week
    static func getCurrentDayOfWeek() -> DayOfWeek {
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
