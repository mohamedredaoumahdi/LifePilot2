import SwiftUI

struct WeeklyScheduleView: View {
    @StateObject private var viewModel = WeeklyScheduleViewModel()
    @State private var showingAddActivity = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Day selector
            daySelector
                .padding(.horizontal)
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(message: error)
            } else if let schedule = viewModel.weeklySchedule {
                scheduleContent(schedule: schedule)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Weekly Schedule")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddActivity = true
                }) {
                    Image(systemName: "plus")
                }
                
                Button(action: {
                    viewModel.regenerateSchedule()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            ActivityFormView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingActivity) { activity in
            ActivityFormView(viewModel: viewModel, activity: activity)
        }
    }
    
    // MARK: - Day Selector
    
    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    DayButton(
                        day: day,
                        isSelected: viewModel.selectedDay == day,
                        onSelect: {
                            viewModel.selectedDay = day
                        }
                    )
                }
            }
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your schedule...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Schedule")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.fetchSchedule()
            }) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("No Schedule Yet")
                .font(.headline)
            
            Text("Generate your weekly schedule based on your accepted recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.regenerateSchedule()
            }) {
                Text("Generate Schedule")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Schedule Content
    
    private func scheduleContent(schedule: WeeklySchedule) -> some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.bottom)
            
            ScrollView {
                VStack(spacing: 16) {
                    let activities = viewModel.activitiesForSelectedDay()
                    
                    if activities.isEmpty {
                        noActivitiesView
                    } else {
                        ForEach(activities) { activity in
                            ActivityCardView(
                                activity: activity,
                                onToggleCompletion: {
                                    viewModel.toggleActivityCompletion(activity)
                                },
                                onEdit: {
                                    viewModel.editingActivity = activity
                                },
                                onDelete: {
                                    viewModel.deleteActivity(activity)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var noActivitiesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No activities for \(viewModel.selectedDay.rawValue)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the + button to add an activity or regenerate your schedule.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Day Button

struct DayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(day.shortName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(width: 40, height: 40)
                    
                    Text(dayNumber(for: day))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func dayNumber(for day: DayOfWeek) -> String {
        // Get the current week's date for this day
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
        
        // Calculate the offset in days
        let daysOffset = targetWeekday - currentWeekday
        
        // Get the date of the target day
        if let targetDate = calendar.date(byAdding: .day, value: daysOffset, to: today) {
            let dayNumber = calendar.component(.day, from: targetDate)
            return String(dayNumber)
        }
        
        // Fallback
        return ""
    }
}

// MARK: - Activity Card View

struct ActivityCardView: View {
    let activity: ScheduledActivity
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time and Title
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(activity.title)
                        .font(.headline)
                }
                
                Spacer()
                
                // Activity Type Badge
                Text(activity.activityType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(activityColor.opacity(0.2))
                    .foregroundColor(activityColor)
                    .cornerRadius(8)
            }
            
            // Description (if available)
            if let description = activity.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Notes (if available)
            if let notes = activity.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button(action: onToggleCompletion) {
                    HStack(spacing: 4) {
                        Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(activity.isCompleted ? .green : .gray)
                        
                        Text(activity.isCompleted ? "Completed" : "Mark as completed")
                            .font(.caption)
                            .foregroundColor(activity.isCompleted ? .green : .gray)
                    }
                }
                
                Spacer()
                
                // Recommendation indicator
                if activity.isRecommended {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        
                        Text("Recommended")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Options button
                Button(action: {
                    showingOptions = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
                .confirmationDialog("Activity Options", isPresented: $showingOptions) {
                    Button("Edit") { onEdit() }
                    Button("Delete", role: .destructive) { onDelete() }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let startTime = formatter.string(from: activity.startTime)
        let endTime = formatter.string(from: activity.endTime)
        
        return "\(startTime) - \(endTime)"
    }
    
    private var activityColor: Color {
        switch activity.color {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .yellow: return .yellow
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

// MARK: - Activity Form View

struct ActivityFormView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: WeeklyScheduleViewModel
    
    // Form state
    @State private var title = ""
    @State private var description = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var activityType: ActivityType = .task
    @State private var activityColor: ActivityColor = .blue
    
    // Optional activity for editing
    var activity: ScheduledActivity?
    
    // Form validation
    private var isValidForm: Bool {
        !title.isEmpty && endDate > startDate
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Activity Details")) {
                    TextField("Title", text: $title)
                    
                    TextField("Description (Optional)", text: $description)
                    
                    TextField("Notes (Optional)", text: $notes)
                }
                
                Section(header: Text("Time")) {
                    DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Activity Type")) {
                    Picker("Type", selection: $activityType) {
                        ForEach(ActivityType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Color")) {
                    Picker("Color", selection: $activityColor) {
                        ForEach(ActivityColor.allCases, id: \.self) { color in
                            HStack {
                                ColorSwatch(color: color)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle(activity == nil ? "Add Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(activity == nil ? "Add" : "Save") {
                        saveActivity()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(!isValidForm)
                }
            }
            .onAppear {
                // If editing an existing activity, populate the form
                if let activity = activity {
                    title = activity.title
                    description = activity.description ?? ""
                    notes = activity.notes ?? ""
                    startDate = activity.startTime
                    endDate = activity.endTime
                    activityType = activity.activityType
                    activityColor = activity.color
                }
            }
        }
    }
    
    private func saveActivity() {
        if let activity = activity {
            // Update existing activity
            let updatedActivity = ScheduledActivity(
                id: activity.id,
                title: title,
                description: description.isEmpty ? nil : description,
                startTime: startDate,
                endTime: endDate,
                activityType: activityType,
                isCompleted: activity.isCompleted,
                isRecommended: activity.isRecommended,
                relatedRecommendationId: activity.relatedRecommendationId,
                color: activityColor,
                notes: notes.isEmpty ? nil : notes
            )
            
            viewModel.updateActivity(updatedActivity)
        } else {
            // Create new activity
            let newActivity = ScheduledActivity(
                title: title,
                description: description.isEmpty ? nil : description,
                startTime: startDate,
                endTime: endDate,
                activityType: activityType,
                color: activityColor,
                notes: notes.isEmpty ? nil : notes
            )
            
            viewModel.addActivity(newActivity)
        }
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let color: ActivityColor
    
    var body: some View {
        Circle()
            .fill(swatchColor)
            .frame(width: 20, height: 20)
    }
    
    private var swatchColor: Color {
        switch color {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .yellow: return .yellow
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

struct WeeklyScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeeklyScheduleView()
        }
    }
}
