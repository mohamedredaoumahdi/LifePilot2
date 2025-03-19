import Foundation
import UIKit
import Combine
import EventKit
import UserNotifications

enum ViewType {
    case list
    case timeline
}

class WeeklyScheduleViewModel: ObservableObject {
    // Published properties
    @Published var weeklySchedule: WeeklySchedule?
    @Published var selectedDay: DayOfWeek = getCurrentDayOfWeek()
    @Published var isLoading = false
    @Published var error: String?
    @Published var showingActivityForm = false
    @Published var editingActivity: ScheduledActivity?
    @Published var viewType: ViewType = .list
    @Published var daysInCurrentWeek: [DayOfWeek] = DayOfWeek.allCases
    
    // Calendar import settings
    @Published var importRange: ImportRange = .oneWeek
    @Published var skipAllDayEvents = true
    @Published var importAsReadOnly = false
    
    // Notification settings
    @Published var globalNotificationsEnabled = true
    @Published var defaultReminderTime: Int = 15
    @Published var weeklyDigestEnabled = false
    @Published var weeklyDigestDay: DayOfWeek = .sunday
    @Published var weeklyDigestTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var notificationSound = "default"
    
    // Services
    private let databaseService: FirebaseDatabaseServiceProtocol
    private let analysisViewModel: PersonalizedAnalysisViewModel
    private let scheduleGeneratorService: ScheduleGeneratorServiceProtocol
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    private var scheduleSubscription: AnyCancellable?
    private var userId: String?
    var currentWeekOffset = 0
    
    // Initialize with dependencies
    init(databaseService: FirebaseDatabaseServiceProtocol = FirebaseDatabaseService(),
         analysisViewModel: PersonalizedAnalysisViewModel = PersonalizedAnalysisViewModel(),
         scheduleGeneratorService: ScheduleGeneratorServiceProtocol = ScheduleGeneratorService()) {
        self.databaseService = databaseService
        self.analysisViewModel = analysisViewModel
        self.scheduleGeneratorService = scheduleGeneratorService
        
        // Subscribe to user profile changes
        setupUserSubscription()
        
        // Load notification settings
        loadNotificationSettings()
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
                    print("WeeklyScheduleViewModel received user ID: \(userId)")
                    self?.setupScheduleListener(userId: userId)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to accepted recommendations changes
        analysisViewModel.$analysis
            .compactMap { $0 }
            .sink { [weak self] analysis in
                print("WeeklyScheduleViewModel received updated analysis with \(analysis.recommendations.count) recommendations")
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
                        print("Error observing schedule: \(error)")
                    }
                },
                receiveValue: { [weak self] schedule in
                    self?.weeklySchedule = schedule
                    if schedule != nil {
                        print("Real-time schedule update received")
                        // Clear the loading state and error if we receive a schedule
                        self?.isLoading = false
                        self?.error = nil
                    } else if self?.weeklySchedule == nil {
                        // No schedule exists yet, try to generate one
                        print("No schedule found, attempting to generate one")
                        self?.regenerateSchedule()
                    }
                }
            )
    }
    
    // MARK: - Public Methods
    
    /// Set user ID explicitly (used when passing from view)
    func setUserId(_ id: String) {
        print("Setting user ID in WeeklyScheduleViewModel: \(id)")
        self.userId = id
        
        // Setup listener and fetch schedule
        setupScheduleListener(userId: id)
    }
    
    /// Load a specific week by offset from current week
    func loadWeek(offset: Int) {
        self.currentWeekOffset = offset
        
        // Update days in current week
        daysInCurrentWeek = getDaysForWeek(offset: offset)
        
        // Adjust selected day if it's not in the current week
        if !daysInCurrentWeek.contains(selectedDay) {
            selectedDay = daysInCurrentWeek.first ?? .monday
        }
    }
    
    /// Get the date for a specific day in the current week
    func getDateForDay(_ day: DayOfWeek, weekOffset: Int = 0) -> Date {
        let today = Date()
        let calendar = Calendar.current
        
        // Get the current weekday (1 = Sunday, 2 = Monday, etc.)
        let currentWeekday = calendar.component(.weekday, from: today)
        
        // Convert our DayOfWeek to Calendar's weekday format
        let targetWeekday: Int
        switch day {
        case .sunday: targetWeekday = 1
        case .monday: targetWeekday = 2
        case .tuesday: targetWeekday = 3
        case .wednesday: targetWeekday = 4
        case .thursday: targetWeekday = 5
        case .friday: targetWeekday = 6
        case .saturday: targetWeekday = 7
        }
        
        // Calculate the difference in days
        var daysToAdd = targetWeekday - currentWeekday
        
        // Adjust for week offset
        daysToAdd += weekOffset * 7
        
        // Get the date of the target day
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
    
    /// Get days for a specific week
    private func getDaysForWeek(offset: Int) -> [DayOfWeek] {
        // Always return the standard week days, starting with Sunday
        return DayOfWeek.allCases
    }
    
    /// Check for time conflicts with existing activities
    func checkTimeConflict(start: Date, end: Date, excluding activityId: String? = nil) -> Bool {
        guard let weeklySchedule = weeklySchedule else { return false }
        
        // Get day of week for the activity
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: start)
        let dayOfWeek: DayOfWeek
        
        switch weekday {
        case 1: dayOfWeek = .sunday
        case 2: dayOfWeek = .monday
        case 3: dayOfWeek = .tuesday
        case 4: dayOfWeek = .wednesday
        case 5: dayOfWeek = .thursday
        case 6: dayOfWeek = .friday
        case 7: dayOfWeek = .saturday
        default: dayOfWeek = .monday
        }
        
        // Find the day in the schedule
        guard let day = weeklySchedule.days.first(where: { $0.dayOfWeek == dayOfWeek }) else {
            return false
        }
        
        // Check for conflicts with existing activities (excluding the one being edited)
        for activity in day.activities {
            if let excludedId = activityId, activity.id == excludedId {
                continue
            }
            
            // Check for overlap
            if (start < activity.endTime && end > activity.startTime) {
                return true
            }
        }
        
        return false
    }
    
    /// Get time conflicts for visualization
    func getTimeConflicts() -> [Date] {
        guard let weeklySchedule = weeklySchedule else { return [] }
        
        var conflicts = [Date]()
        
        // Find the day in the schedule
        guard let day = weeklySchedule.days.first(where: { $0.dayOfWeek == selectedDay }) else {
            return []
        }
        
        // Build a list of activities
        let activities = day.activities
        
        // Check for overlaps
        for i in 0..<activities.count {
            for j in (i+1)..<activities.count {
                let activity1 = activities[i]
                let activity2 = activities[j]
                
                // Check for overlap
                if activity1.startTime < activity2.endTime && activity1.endTime > activity2.startTime {
                    // Add conflict at the start time of the overlap
                    let conflictStart = max(activity1.startTime, activity2.startTime)
                    conflicts.append(conflictStart)
                }
            }
        }
        
        return conflicts
    }
    
    /// Get activities for the selected day
    func activitiesForSelectedDay() -> [ScheduledActivity] {
        guard let weeklySchedule = weeklySchedule,
              let day = weeklySchedule.days.first(where: { $0.dayOfWeek == selectedDay }) else {
            return []
        }
        
        return day.activities.sorted { $0.startTime < $1.startTime }
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
                        print("Error fetching schedule: \(error)")
                    }
                },
                receiveValue: { [weak self] schedule in
                    if let schedule = schedule {
                        print("Successfully fetched schedule with \(schedule.days.count) days")
                        self?.weeklySchedule = schedule
                    } else {
                        print("No schedule found, will try to generate one")
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
                
                // Schedule notification if enabled
                if activity.enableReminders {
                    scheduleNotification(for: activity)
                }
                
                // If this is a recurring activity, add instances for future dates
                if let recurrenceRule = activity.recurrenceRule {
                    addRecurringInstances(activity, recurrenceRule: recurrenceRule)
                }
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
                
                // Schedule notification if enabled
                if activity.enableReminders {
                    scheduleNotification(for: activity)
                }
                
                // If this is a recurring activity, add instances for future dates
                if let recurrenceRule = activity.recurrenceRule {
                    addRecurringInstances(activity, recurrenceRule: recurrenceRule)
                }
            }
        }
    }
    
    /// Update an existing activity
    func updateActivity(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day that contains the activity
        let dayOfWeek = getDayOfWeek(from: activity.startTime)
        
        // First, check if the activity is moved to a different day
        var oldDay: DaySchedule?
        var oldDayIndex: Int?
        
        // Find the day containing the original activity
        for (index, day) in weeklySchedule.days.enumerated() {
            if day.activities.contains(where: { $0.id == activity.id }) {
                oldDay = day
                oldDayIndex = index
                break
            }
        }
        
        // Remove from old day if found and different from new day
        if let oldDay = oldDay, let oldDayIndex = oldDayIndex, oldDay.dayOfWeek != dayOfWeek {
            weeklySchedule.days[oldDayIndex].activities.removeAll { $0.id == activity.id }
        }
        
        // Add to new day or update in existing day
        if let dayIndex = weeklySchedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            // If moving from different day, add to new day
            if oldDay?.dayOfWeek != dayOfWeek {
                weeklySchedule.days[dayIndex].activities.append(activity)
            } else {
                // Update in same day
                if let activityIndex = weeklySchedule.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) {
                    weeklySchedule.days[dayIndex].activities[activityIndex] = activity
                }
            }
            
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
            
            // Update notification if enabled
            if activity.enableReminders {
                cancelNotification(for: activity.id)
                scheduleNotification(for: activity)
            } else {
                cancelNotification(for: activity.id)
            }
            
            // If this is a recurring activity, handle recurrence updates
            handleRecurrenceUpdate(activity)
        }
    }
    
    /// Delete an activity
    func deleteActivity(_ activity: ScheduledActivity) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Cancel any notifications for this activity
        cancelNotification(for: activity.id)
        
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
        
        // Handle recurrence if needed
        if activity.recurrenceRule != nil {
            // Determine if we should delete all future instances
            // For now, let's automatically delete all recurring instances
            deleteRecurringInstances(activity)
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
    
    /// Reschedule an activity (used for drag-and-drop)
    func rescheduleActivity(_ activity: ScheduledActivity, newTime: Date) {
        guard var weeklySchedule = weeklySchedule else { return }
        
        // Find the day that contains the activity
        for dayIndex in 0..<weeklySchedule.days.count {
            // Find the activity to update
            if let activityIndex = weeklySchedule.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) {
                // Calculate duration
                let duration = activity.endTime.timeIntervalSince(activity.startTime)
                
                // Create updated activity with new times
                var updatedActivity = activity
                updatedActivity.startTime = newTime
                updatedActivity.endTime = newTime.addingTimeInterval(duration)
                
                // Update the activity
                weeklySchedule.days[dayIndex].activities[activityIndex] = updatedActivity
                
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
                
                // Update notification if enabled
                if activity.enableReminders {
                    cancelNotification(for: activity.id)
                    scheduleNotification(for: updatedActivity)
                }
                
                break
            }
        }
    }
    
    /// Import events from device calendar
    func importFromCalendars(identifiers: [String], eventStore: EKEventStore, completion: @escaping (ImportResult) -> Void) {
        guard let userId = userId else {
            completion(ImportResult(imported: 0, errors: 1))
            return
        }
        
        // Create calendar instances
        let calendars = identifiers.compactMap { identifier in
            eventStore.calendar(withIdentifier: identifier)
        }
        
        if calendars.isEmpty {
            completion(ImportResult(imported: 0, errors: 1))
            return
        }
        
        // Calculate date range
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: importRange.rawValue, to: startDate) ?? Date()
        
        // Create predicate for date range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        // Filter all-day events if needed
        let filteredEvents = skipAllDayEvents ? events.filter { !$0.isAllDay } : events
        
        var importedCount = 0
        var errorCount = 0
        
        // Load existing schedule or create a new one
        var schedule = weeklySchedule ?? WeeklySchedule(userId: userId)
        
        // Import each event
        for event in filteredEvents {
            do {
                // Create activity from event
                let activity = ScheduledActivity(
                    title: event.title ?? "Untitled Event",
                    description: event.notes,
                    startTime: event.startDate,
                    endTime: event.endDate,
                    activityType: determineActivityType(from: event),
                    isCompleted: false,
                    isRecommended: false,
                    color: determineColor(from: event),
                    notes: importAsReadOnly ? "Imported from Calendar (\(event.calendar.title))" : nil,
                    enableReminders: false // Don't duplicate notifications
                )
                
                // Find the day to add the activity to
                let dayOfWeek = getDayOfWeek(from: activity.startTime)
                
                if let dayIndex = schedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
                    // Add the activity
                    schedule.days[dayIndex].activities.append(activity)
                    importedCount += 1
                }
            } catch {
                errorCount += 1
            }
        }
        
        // Sort activities by start time
        for i in 0..<schedule.days.count {
            schedule.days[i].activities.sort { a, b in
                return a.startTime < b.startTime
            }
        }
        
        // Update the schedule
        self.weeklySchedule = schedule
        
        // Update the last modified date
        schedule.lastModified = Date()
        
        // Save to Firebase
        saveSchedule(schedule)
        
        // Return result
        completion(ImportResult(imported: importedCount, errors: errorCount))
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
                    print("No accepted recommendations found, generating empty schedule")
                    let emptySchedule = WeeklySchedule(userId: userId)
                    self.weeklySchedule = emptySchedule
                    self.isLoading = false
                    self.saveSchedule(emptySchedule)
                    return
                }
                
                // Preserve existing custom activities
                var customActivities: [ScheduledActivity] = []
                if let existingSchedule = self.weeklySchedule {
                    for day in existingSchedule.days {
                        let nonRecommended = day.activities.filter { !$0.isRecommended }
                        customActivities.append(contentsOf: nonRecommended)
                    }
                }
                
                // Generate new schedule
                var newSchedule = self.scheduleGeneratorService.generateWeeklySchedule(
                    userId: userId,
                    recommendations: acceptedRecommendations
                )
                
                // Add custom activities back to the new schedule
                for activity in customActivities {
                    let dayOfWeek = self.getDayOfWeek(from: activity.startTime)
                    if let dayIndex = newSchedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
                        newSchedule.days[dayIndex].activities.append(activity)
                    }
                }
                
                // Sort activities by start time for each day
                for i in 0..<newSchedule.days.count {
                    newSchedule.days[i].activities.sort { a, b in
                        return a.startTime < b.startTime
                    }
                }
                
                // Update state
                DispatchQueue.main.async {
                    self.weeklySchedule = newSchedule
                    self.isLoading = false
                    
                    // Save to Firebase
                    self.saveSchedule(newSchedule)
                    
                    // Schedule notifications for all activities
                    self.rebuildAllNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Methods
    
    /// Schedule a notification for an activity
    func scheduleNotification(for activity: ScheduledActivity) {
        guard globalNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = activity.title
        content.body = activity.description ?? "It's time for your scheduled activity"
        content.sound = notificationSound == "none" ? nil : UNNotificationSound.default
        content.badge = 1
        
        // Calculate notification time
        let minutesBefore = activity.reminderMinutesBefore
        let triggerDate = activity.startTime.addingTimeInterval(-Double(minutesBefore * 60))
        
        // If the trigger date is in the past, don't schedule
        if triggerDate <= Date() {
            return
        }
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        // Create a request with a unique identifier
        let request = UNNotificationRequest(identifier: "activity-\(activity.id)", content: content, trigger: trigger)
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for \(activity.title) at \(triggerDate)")
            }
        }
    }
    
    /// Cancel a notification for an activity
    func cancelNotification(for activityId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["activity-\(activityId)"])
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Rebuild all notifications for current schedule
    func rebuildAllNotifications() {
        guard globalNotificationsEnabled, let schedule = weeklySchedule else { return }
        
        // First, cancel all existing notifications
        cancelAllNotifications()
        
        // Schedule notifications for all activities
        for day in schedule.days {
            for activity in day.activities {
                if activity.enableReminders {
                    scheduleNotification(for: activity)
                }
            }
        }
        
        // Schedule weekly digest if enabled
        if weeklyDigestEnabled {
            scheduleWeeklyDigest(day: weeklyDigestDay, time: weeklyDigestTime)
        }
    }
    
    /// Schedule weekly digest notification
    func scheduleWeeklyDigest(day: DayOfWeek, time: Date) {
        guard globalNotificationsEnabled, weeklyDigestEnabled else { return }
        
        // Cancel any existing weekly digest notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])
        
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Schedule"
        content.body = "Here's your weekly agenda. Tap to view your schedule."
        content.sound = notificationSound == "none" ? nil : UNNotificationSound.default
        
        // Convert day of week to weekday component (1 = Sunday, 2 = Monday, etc.)
        var weekday: Int
        switch day {
        case .sunday: weekday = 1
        case .monday: weekday = 2
        case .tuesday: weekday = 3
        case .wednesday: weekday = 4
        case .thursday: weekday = 5
        case .friday: weekday = 6
        case .saturday: weekday = 7
        }
        
        // Extract hour and minute from digest time
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Create date components for the trigger
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the notification request
        let request = UNNotificationRequest(identifier: "weekly-digest", content: content, trigger: trigger)
        
        // Add the request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling weekly digest: \(error.localizedDescription)")
            } else {
                print("Weekly digest scheduled for \(day.rawValue) at \(hour):\(minute)")
            }
        }
    }
    
    /// Cancel weekly digest notification
    func cancelWeeklyDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])
    }
    
    /// Save notification settings to user defaults
    func saveNotificationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(globalNotificationsEnabled, forKey: "globalNotificationsEnabled")
        defaults.set(defaultReminderTime, forKey: "defaultReminderTime")
        defaults.set(weeklyDigestEnabled, forKey: "weeklyDigestEnabled")
        defaults.set(weeklyDigestDay.rawValue, forKey: "weeklyDigestDay")
        defaults.set(weeklyDigestTime, forKey: "weeklyDigestTime")
        defaults.set(notificationSound, forKey: "notificationSound")
    }
    /// Load notification settings from user defaults
        private func loadNotificationSettings() {
            let defaults = UserDefaults.standard
            globalNotificationsEnabled = defaults.bool(forKey: "globalNotificationsEnabled")
            defaultReminderTime = defaults.integer(forKey: "defaultReminderTime")
            weeklyDigestEnabled = defaults.bool(forKey: "weeklyDigestEnabled")
            
            if let dayString = defaults.string(forKey: "weeklyDigestDay"),
               let day = DayOfWeek(rawValue: dayString) {
                weeklyDigestDay = day
            }
            
            if let time = defaults.object(forKey: "weeklyDigestTime") as? Date {
                weeklyDigestTime = time
            }
            
            if let sound = defaults.string(forKey: "notificationSound") {
                notificationSound = sound
            }
        }
        
        // MARK: - Statistics Methods
        
        /// Get activity statistics for a specific time range
        func getActivityStatistics(for timeRange: TimeRangeOption) -> ActivityStats {
            guard let schedule = weeklySchedule else {
                return ActivityStats(
                    completedCount: 0,
                    pendingCount: 0,
                    totalCount: 0,
                    completionRate: 0,
                    activityTypeCounts: [:],
                    activityTypeDurations: [:],
                    totalDuration: 0,
                    activities: []
                )
            }
            
            // Get the relevant date range
            let now = Date()
            let calendar = Calendar.current
            
            var startDate: Date
            
            switch timeRange {
            case .week:
                // Current week
                startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            case .month:
                // Current month
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            case .allTime:
                // All time (use a date far in the past)
                startDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            }
            
            // Collect all activities within the time range
            var allActivities: [ScheduledActivity] = []
            
            for day in schedule.days {
                let activitiesInRange = day.activities.filter { activity in
                    return activity.startTime >= startDate && activity.startTime <= now
                }
                allActivities.append(contentsOf: activitiesInRange)
            }
            
            // Calculate statistics
            let totalCount = allActivities.count
            let completedCount = allActivities.filter { $0.isCompleted }.count
            let pendingCount = totalCount - completedCount
            
            // Calculate completion rate (avoid division by zero)
            let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            // Activity type counts
            var activityTypeCounts: [ActivityType: Int] = [:]
            for activity in allActivities {
                activityTypeCounts[activity.activityType, default: 0] += 1
            }
            
            // Activity type durations
            var activityTypeDurations: [ActivityType: TimeInterval] = [:]
            var totalDuration: TimeInterval = 0
            
            for activity in allActivities {
                let duration = activity.endTime.timeIntervalSince(activity.startTime)
                activityTypeDurations[activity.activityType, default: 0] += duration
                totalDuration += duration
            }
            
            return ActivityStats(
                completedCount: completedCount,
                pendingCount: pendingCount,
                totalCount: totalCount,
                completionRate: completionRate,
                activityTypeCounts: activityTypeCounts,
                activityTypeDurations: activityTypeDurations,
                totalDuration: totalDuration,
                activities: allActivities.sorted { $0.startTime > $1.startTime } // Most recent first
            )
        }
        
        // MARK: - Recurrence Methods
        
        /// Add recurring instances for a newly created recurring activity
        private func addRecurringInstances(_ activity: ScheduledActivity, recurrenceRule: RecurrenceRule) {
            // For simplicity, we'll just add a few instances for now
            // In a real app, you'd implement more sophisticated recurrence logic
            
            guard let userId = userId else { return }
            
            let calendar = Calendar.current
            var currentDate = activity.startTime
            
            // Add up to 10 instances
            for _ in 1...10 {
                var nextDate: Date?
                
                switch recurrenceRule.frequency {
                case .daily:
                    nextDate = calendar.date(byAdding: .day, value: recurrenceRule.interval, to: currentDate)
                    
                case .weekly:
                    nextDate = calendar.date(byAdding: .day, value: 7 * recurrenceRule.interval, to: currentDate)
                    
                    // If specific days of week are selected, adjust the next date
                    if let daysOfWeek = recurrenceRule.daysOfWeek, !daysOfWeek.isEmpty {
                        // This is simplified logic - real apps would have more complex handling
                        // For now, just use the first day in the list
                        if let firstDay = daysOfWeek.first {
                            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextDate!)
                            components.weekday = firstDay
                            nextDate = calendar.date(from: components)
                        }
                    }
                    
                case .monthly:
                    nextDate = calendar.date(byAdding: .month, value: recurrenceRule.interval, to: currentDate)
                    
                default:
                    break
                }
                
                // If we have a valid next date, create a new instance
                if let nextDate = nextDate {
                    // Calculate duration
                    let duration = activity.endTime.timeIntervalSince(activity.startTime)
                    
                    // Create a new activity instance
                    let newActivity = ScheduledActivity(
                        title: activity.title,
                        description: activity.description,
                        startTime: nextDate,
                        endTime: nextDate.addingTimeInterval(duration),
                        activityType: activity.activityType,
                        isCompleted: false,
                        isRecommended: activity.isRecommended,
                        relatedRecommendationId: activity.relatedRecommendationId,
                        color: activity.color,
                        notes: activity.notes,
                        enableReminders: activity.enableReminders,
                        reminderMinutesBefore: activity.reminderMinutesBefore,
                        recurrenceRule: recurrenceRule, // Keep the recurrence rule
                        recurringParentId: activity.id // Link to parent
                    )
                    
                    // Add to schedule
                    if var schedule = weeklySchedule {
                        let dayOfWeek = getDayOfWeek(from: nextDate)
                        
                        if let dayIndex = schedule.days.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
                            schedule.days[dayIndex].activities.append(newActivity)
                            
                            // Sort activities
                            schedule.days[dayIndex].activities.sort { a, b in
                                return a.startTime < b.startTime
                            }
                        }
                        
                        // Update schedule
                        self.weeklySchedule = schedule
                        
                        // Schedule notification if enabled
                        if newActivity.enableReminders {
                            scheduleNotification(for: newActivity)
                        }
                    }
                    
                    // Update current date for next iteration
                    currentDate = nextDate
                } else {
                    break
                }
            }
            
            // Save the updated schedule
            if let schedule = weeklySchedule {
                saveSchedule(schedule)
            }
        }
        
        /// Handle updates to a recurring activity
        private func handleRecurrenceUpdate(_ activity: ScheduledActivity) {
            // TODO: Implement proper recurrence update logic
            // For now, we'll just regenerate instances
            
            // First, delete existing instances
            deleteRecurringInstances(activity)
            
            // Then, if it's still recurring, regenerate instances
            if let recurrenceRule = activity.recurrenceRule {
                addRecurringInstances(activity, recurrenceRule: recurrenceRule)
            }
        }
        
        /// Delete all recurring instances of an activity
        private func deleteRecurringInstances(_ activity: ScheduledActivity) {
            guard var schedule = weeklySchedule else { return }
            
            // Delete all activities with the same recurring parent ID
            for dayIndex in 0..<schedule.days.count {
                schedule.days[dayIndex].activities.removeAll {
                    $0.recurringParentId == activity.id || $0.id == activity.id
                }
            }
            
            // Update schedule
            self.weeklySchedule = schedule
            
            // Save the updated schedule
            saveSchedule(schedule)
        }
        
        // MARK: - Private Methods
        
        /// Determine color based on event type
        private func determineColor(from event: EKEvent) -> ActivityColor {
            if let calendarColor = event.calendar.cgColor {
                let color = UIColor(cgColor: calendarColor)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                
                if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    // Simplified color matching - in a real app you'd do more sophisticated color mapping
                    if red > 0.7 && green < 0.3 && blue < 0.3 {
                        return .red
                    } else if green > 0.7 && red < 0.3 && blue < 0.3 {
                        return .green
                    } else if blue > 0.7 && red < 0.3 && green < 0.3 {
                        return .blue
                    } else if red > 0.7 && green > 0.7 && blue < 0.3 {
                        return .yellow
                    } else if red > 0.7 && blue > 0.7 && green < 0.3 {
                        return .purple
                    } else if green > 0.7 && blue > 0.7 && red < 0.3 {
                        return .teal
                    } else if red > 0.7 && green > 0.3 && blue < 0.3 {
                        return .orange
                    } else if red > 0.7 && green < 0.3 && blue > 0.3 {
                        return .pink
                    }
                }
            }
            
            // Default color
            return .blue
        }
        
        /// Determine activity type based on event category
        private func determineActivityType(from event: EKEvent) -> ActivityType {
            // Check for keywords in the event title and notes
            let title = event.title?.lowercased() ?? ""
            let notes = event.notes?.lowercased() ?? ""
            let combined = title + " " + notes
            
            if combined.contains("exercise") || combined.contains("workout") || combined.contains("gym") || combined.contains("run") {
                return .exercise
            } else if combined.contains("meal") || combined.contains("lunch") || combined.contains("dinner") || combined.contains("breakfast") {
                return .meal
            } else if combined.contains("work") || combined.contains("meeting") || combined.contains("call") || combined.contains("conference") {
                return .work
            } else if combined.contains("learn") || combined.contains("study") || combined.contains("class") || combined.contains("course") {
                return .learning
            } else if combined.contains("meditate") || combined.contains("yoga") || combined.contains("mindfulness") {
                return .mindfulness
            } else if combined.contains("sleep") || combined.contains("nap") || combined.contains("rest") {
                return .sleep
            } else if combined.contains("leisure") || combined.contains("fun") || combined.contains("relax") || combined.contains("entertainment") {
                return .leisure
            } else if combined.contains("habit") {
                return .habit
            }
            
            // Default to task
            return .task
        }
        
        /// Save the schedule to Firebase
        private func saveSchedule(_ schedule: WeeklySchedule) {
            print("Saving schedule to Firebase for userId: \(schedule.userId)")
            
            databaseService.saveSchedule(schedule)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = "Error saving schedule: \(error.localizedDescription)"
                            print("Error saving schedule: \(error)")
                        } else {
                            print("Schedule saved successfully to Firebase")
                        }
                    },
                    receiveValue: { _ in
                        // Successfully saved
                    }
                )
                .store(in: &cancellables)
        }
        
        /// Get the day of week from a date
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
        
        /// Format time to display in the UI
        func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
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
    }
