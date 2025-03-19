import SwiftUI



struct WeeklyScheduleView: View {
    @StateObject private var viewModel = WeeklyScheduleViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingAddActivity = false
    @State private var showingRegenerateConfirmation = false
    @State private var showingCalendarImport = false
    @State private var showingNotificationSettings = false
    @State private var showingStatistics = false
    @State private var previousUserId: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Week navigation
            weekNavigator
                .padding(.horizontal)
            
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
                // Statistics button
                Button(action: {
                    showingStatistics = true
                }) {
                    Image(systemName: "chart.bar.fill")
                }
                
                // Add activity button
                Button(action: {
                    showingAddActivity = true
                }) {
                    Image(systemName: "plus")
                }
                
                // More options menu
                Menu {
                    Button(action: {
                        viewModel.regenerateSchedule()
                    }) {
                        Label("Regenerate Schedule", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        showingCalendarImport = true
                    }) {
                        Label("Import Calendar Events", systemImage: "calendar.badge.plus")
                    }
                    
                    Button(action: {
                        showingNotificationSettings = true
                    }) {
                        Label("Notification Settings", systemImage: "bell")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            ActivityFormView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingActivity) { activity in
            ActivityFormView(viewModel: viewModel, activity: activity)
        }
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingStatistics) {
            ActivityStatisticsView(viewModel: viewModel)
        }
        .alert(isPresented: $showingRegenerateConfirmation) {
            Alert(
                title: Text("Regenerate Schedule?"),
                message: Text("This will create a new schedule based on your accepted recommendations. Any custom activities will be preserved."),
                primaryButton: .default(Text("Regenerate")) {
                    viewModel.regenerateSchedule()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            print("WeeklyScheduleView appeared, authViewModel.currentUser: \(String(describing: authViewModel.currentUser))")
            
            // Make sure we have a user ID before attempting to fetch schedule
            if let user = authViewModel.currentUser {
                let userId = user.id
                print("Setting user ID: \(userId)")
                viewModel.setUserId(userId)
                previousUserId = userId
            }
        }
        .onReceive(authViewModel.$currentUser) { newUser in
            print("Auth state changed in WeeklyScheduleView, new user: \(String(describing: newUser))")
            
            // Check if user ID has changed
            let newUserId = newUser?.id
            if newUserId != previousUserId {
                if let userId = newUserId {
                    print("User ID changed from \(String(describing: previousUserId)) to \(userId)")
                    viewModel.setUserId(userId)
                    previousUserId = userId
                }
            }
        }
    }
    
    // MARK: - Week Navigator
    
    private var weekNavigator: some View {
        HStack {
            Button(action: {
                viewModel.loadWeek(offset: viewModel.currentWeekOffset - 1)
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack {
                Text(weekRangeString)
                    .font(.headline)
                
                if viewModel.currentWeekOffset != 0 {
                    Button("Today") {
                        viewModel.loadWeek(offset: 0)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.loadWeek(offset: viewModel.currentWeekOffset + 1)
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var weekRangeString: String {
        let calendar = Calendar.current
        let today = Date()
        
        // Get start date with correct offset
        guard let startDate = calendar.date(byAdding: .day, value: 7 * viewModel.currentWeekOffset, to: today) else {
            return "Current Week"
        }
        
        // Find start of week containing the start date
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)) else {
            return "Current Week"
        }
        
        // Calculate end of week
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return "Current Week"
        }
        
        // Format dates
        let dateFormatter = DateFormatter()
        
        // If start and end are in the same month
        if calendar.component(.month, from: startOfWeek) == calendar.component(.month, from: endOfWeek) {
            dateFormatter.dateFormat = "MMM d"
            let startString = dateFormatter.string(from: startOfWeek)
            dateFormatter.dateFormat = "d, yyyy"
            let endString = dateFormatter.string(from: endOfWeek)
            return "\(startString)-\(endString)"
        } else {
            // If they span different months
            dateFormatter.dateFormat = "MMM d"
            let startString = dateFormatter.string(from: startOfWeek)
            let endString = dateFormatter.string(from: endOfWeek)
            dateFormatter.dateFormat = ", yyyy"
            let yearString = dateFormatter.string(from: endOfWeek)
            return "\(startString)-\(endString)\(yearString)"
        }
    }
    
    // MARK: - Day Selector
    
    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.daysInCurrentWeek, id: \.self) { day in
                    DayButton(
                        day: day,
                        date: viewModel.getDateForDay(day, weekOffset: viewModel.currentWeekOffset),
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
                if let userId = authViewModel.currentUser?.id {
                    viewModel.setUserId(userId)
                }
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
            
            Text("Generate your weekly schedule based on your accepted recommendations or add activities manually.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
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
                
                Button(action: {
                    showingAddActivity = true
                }) {
                    Text("Add Activity Manually")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingCalendarImport = true
                }) {
                    Text("Import from Calendar")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
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
            
            if viewModel.viewType == .list {
                listViewContent(schedule: schedule)
            } else {
                timelineViewContent(schedule: schedule)
            }
            
            // View type toggle
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.viewType = viewModel.viewType == .list ? .timeline : .list
                    }) {
                        Image(systemName: viewModel.viewType == .list ? "clock" : "list.bullet")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func listViewContent(schedule: WeeklySchedule) -> some View {
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
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private func timelineViewContent(schedule: WeeklySchedule) -> some View {
        // Time slots for timeline view (30-minute intervals from 6 AM to 10 PM)
        let timeSlots = stride(from: 6, to: 22, by: 0.5).map { $0 }
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Time labels and grid
                HStack(alignment: .top, spacing: 0) {
                    // Time column
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(timeSlots, id: \.self) { hour in
                            Text(formatTimeSlot(hour))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: 60)
                                .frame(width: 50)
                        }
                    }
                    
                    // Activity area
                    ZStack(alignment: .top) {
                        // Time grid lines
                        VStack(spacing: 0) {
                            ForEach(timeSlots, id: \.self) { hour in
                                Divider()
                                    .padding(.vertical, 29.5)
                            }
                        }
                        
                        // Activities for the selected day
                        let activities = viewModel.activitiesForSelectedDay()
                        
                        ForEach(activities) { activity in
                            ActivityTimelineItem(
                                activity: activity,
                                onTap: {
                                    viewModel.editingActivity = activity
                                }
                            )
                            .position(positionForActivity(activity))
                            .gesture(
                                DragGesture()
                                    .onChanged { _ in }
                                    .onEnded { value in
                                        // Calculate new time based on drag position
                                        let newTime = timeFromPosition(value.location)
                                        viewModel.rescheduleActivity(activity, newTime: newTime)
                                    }
                            )
                        }
                        
                        // Current time indicator
                        if viewModel.currentWeekOffset == 0 && viewModel.selectedDay == WeeklyScheduleViewModel.getCurrentDayOfWeek() {
                            currentTimeIndicator
                        }
                        
                        // Conflict indicators
                        ForEach(viewModel.getTimeConflicts(), id: \.hashValue) { time in
                            conflictIndicator(time: time)
                        }
                    }
                    .frame(height: CGFloat(timeSlots.count) * 60)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // No activities message if needed
                if viewModel.activitiesForSelectedDay().isEmpty {
                    Text("No activities scheduled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var currentTimeIndicator: some View {
        GeometryReader { geometry in
            let now = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            // Calculate position (hours since 6 AM)
            let hourOffset = Double(hour) + Double(minute) / 60.0 - 6.0
            
            // Only show if within the displayed time range
            if hourOffset >= 0 && hourOffset <= 16 {
                let yPosition = hourOffset * 60.0
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.red)
                        .frame(height: 2)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                .position(x: geometry.size.width / 2, y: yPosition)
            }
        }
    }
    
    private func conflictIndicator(time: Date) -> some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Calculate position (hours since 6 AM)
        let hourOffset = Double(hour) + Double(minute) / 60.0 - 6.0
        
        return Group {
            // Only show if within the displayed time range
            if hourOffset >= 0 && hourOffset <= 16 {
                let yPosition = hourOffset * 60.0
                
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                }
                .position(x: UIScreen.main.bounds.width / 2 - 50, y: yPosition)
            } else {
                // This empty view will be invisible but maintains type consistency
                EmptyView()
            }
        }
    }
    
    private func formatTimeSlot(_ hour: Double) -> String {
        let isHalfHour = hour.truncatingRemainder(dividingBy: 1) != 0
        let hourInt = Int(hour)
        let minuteInt = isHalfHour ? 30 : 0
        
        let dateComponents = DateComponents(hour: hourInt, minute: minuteInt)
        if let date = Calendar.current.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return ""
    }
    
    private func positionForActivity(_ activity: ScheduledActivity) -> CGPoint {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: activity.startTime)
        let startMinute = calendar.component(.minute, from: activity.startTime)
        
        // Calculate position (hours since 6 AM)
        let hourOffset = Double(startHour) + Double(startMinute) / 60.0 - 6.0
        let yPosition = hourOffset * 60.0 + 30.0 // Add 30 for centering
        
        // X position (centered in the available space)
        let xPosition = UIScreen.main.bounds.width / 2
        
        return CGPoint(x: xPosition, y: yPosition)
    }
    
    private func timeFromPosition(_ position: CGPoint) -> Date {
        // Convert Y position to time
        let hourOffset = position.y / 60.0 + 6.0 // 6 AM is the start time
        
        // Round to nearest 15 minutes
        let hourComponent = Int(hourOffset)
        let minuteFraction = hourOffset - Double(hourComponent)
        let minuteComponent: Int
        
        if minuteFraction < 0.25 {
            minuteComponent = 0
        } else if minuteFraction < 0.5 {
            minuteComponent = 15
        } else if minuteFraction < 0.75 {
            minuteComponent = 30
        } else {
            minuteComponent = 45
        }
        
        // Create date components
        var components = Calendar.current.dateComponents([.year, .month, .day], from: viewModel.getDateForDay(viewModel.selectedDay, weekOffset: viewModel.currentWeekOffset))
        components.hour = hourComponent
        components.minute = minuteComponent
        
        return Calendar.current.date(from: components) ?? Date()
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
            
            Button(action: {
                showingAddActivity = true
            }) {
                Text("Add Activity")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Activity Timeline Item

struct ActivityTimelineItem: View {
    let activity: ScheduledActivity
    let onTap: () -> Void
    
    private var activityDuration: TimeInterval {
        return activity.endTime.timeIntervalSince(activity.startTime)
    }
    
    private var activityHeight: CGFloat {
        // Convert duration to height (1 hour = 60 points)
        return max(30, CGFloat(activityDuration / 60) * 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if activityHeight > 50 {
                Text(timeRangeString)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(8)
        .frame(width: UIScreen.main.bounds.width - 80, height: activityHeight)
        .background(activityColor.opacity(0.9))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
    
    private var timeRangeString: String {
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
        case .yellow: return Color(UIColor.systemYellow)
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

// MARK: - Day Button

struct DayButton: View {
    let day: DayOfWeek
    let date: Date
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(day.shortName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 40, height: 40)
                    
                    Text(dayNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else {
            return .primary
        }
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
            
            // Recurrence indicator if this is a recurring activity
            if activity.recurrenceRule != nil {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(.blue)
                    
                    Text(recurrenceText)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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
    
    private var recurrenceText: String {
        guard let rule = activity.recurrenceRule else { return "" }
        
        switch rule.frequency {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        default:
            return "Recurring"
        }
    }
    
    private var activityColor: Color {
        switch activity.color {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .yellow: return Color(UIColor.systemYellow)
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

// MARK: - Recurrence End Option
enum RecurrenceEndOption {
    case never
    case onDate
    case afterOccurrences
}

// MARK: - Weekday Selector
struct WeekdaySelector: View {
    @Binding var selectedDays: [Int]
    
    private let weekdays = [
        (1, "Sun"),
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Repeat on")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(weekdays, id: \.0) { day in
                    Button(action: {
                        toggleDay(day.0)
                    }) {
                        Text(day.1)
                            .font(.caption)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day.0) ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedDays.contains(day.0) ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
            selectedDays.sort()
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
       @State private var enableNotifications = true
       @State private var reminderTime: Int = 15 // Minutes before
       
       // Recurrence options
       @State private var isRecurring = false
       @State private var recurrenceFrequency: RecurrenceRule.Frequency = .weekly
       @State private var recurrenceInterval: Int = 1
       @State private var selectedDaysOfWeek: [Int] = []
       @State private var recurrenceEndOption: RecurrenceEndOption = .never
       @State private var recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
       @State private var recurrenceOccurrences = 10
       
       // Time conflict checking
       @State private var hasTimeConflict = false
       @State private var showingConflictAlert = false
       
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
                           .onChange(of: startDate) { _ in
                               checkForTimeConflicts()
                           }
                       
                       DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                           .onChange(of: endDate) { _ in
                               checkForTimeConflicts()
                           }
                       
                       if hasTimeConflict {
                           HStack {
                               Image(systemName: "exclamationmark.triangle.fill")
                                   .foregroundColor(.orange)
                               Text("This time conflicts with another activity")
                                   .font(.caption)
                                   .foregroundColor(.orange)
                           }
                       }
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
                   
                   Section(header: Text("Reminders")) {
                       Toggle("Enable Reminders", isOn: $enableNotifications)
                       
                       if enableNotifications {
                           Picker("Remind Me", selection: $reminderTime) {
                               Text("At time of activity").tag(0)
                               Text("5 minutes before").tag(5)
                               Text("15 minutes before").tag(15)
                               Text("30 minutes before").tag(30)
                               Text("1 hour before").tag(60)
                           }
                       }
                   }
                   
                   Section(header: Text("Recurrence")) {
                       Toggle("Repeat This Activity", isOn: $isRecurring)
                       
                       if isRecurring {
                           Picker("Frequency", selection: $recurrenceFrequency) {
                               Text("Daily").tag(RecurrenceRule.Frequency.daily)
                               Text("Weekly").tag(RecurrenceRule.Frequency.weekly)
                               Text("Monthly").tag(RecurrenceRule.Frequency.monthly)
                               Text("Yearly").tag(RecurrenceRule.Frequency.yearly)
                           }
                           .pickerStyle(SegmentedPickerStyle())
                           
                           Stepper(value: $recurrenceInterval, in: 1...30) {
                               Text("Every \(recurrenceInterval) \(frequencyLabel(recurrenceFrequency, recurrenceInterval))")
                           }
                           
                           if recurrenceFrequency == .weekly {
                               WeekdaySelector(selectedDays: $selectedDaysOfWeek)
                           }
                           
                           Picker("Ends", selection: $recurrenceEndOption) {
                               Text("Never").tag(RecurrenceEndOption.never)
                               Text("On Date").tag(RecurrenceEndOption.onDate)
                               Text("After").tag(RecurrenceEndOption.afterOccurrences)
                           }
                           
                           if recurrenceEndOption == .onDate {
                               DatePicker("End Date", selection: $recurrenceEndDate, displayedComponents: [.date])
                           } else if recurrenceEndOption == .afterOccurrences {
                               Stepper(value: $recurrenceOccurrences, in: 1...100) {
                                   Text("After \(recurrenceOccurrences) occurrences")
                               }
                           }
                       }
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
                           if hasTimeConflict {
                               showingConflictAlert = true
                           } else {
                               saveActivity()
                               presentationMode.wrappedValue.dismiss()
                           }
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
                       enableNotifications = activity.enableReminders
                       reminderTime = activity.reminderMinutesBefore
                       
                       // Set up recurrence if applicable
                       if let recurrenceRule = activity.recurrenceRule {
                           isRecurring = true
                           recurrenceFrequency = recurrenceRule.frequency
                           recurrenceInterval = recurrenceRule.interval
                           
                           if let daysOfWeek = recurrenceRule.daysOfWeek {
                               selectedDaysOfWeek = daysOfWeek
                           }
                           
                           if let endDate = recurrenceRule.endDate {
                               recurrenceEndOption = .onDate
                               recurrenceEndDate = endDate
                           } else if let occurrences = recurrenceRule.occurrences {
                               recurrenceEndOption = .afterOccurrences
                               recurrenceOccurrences = occurrences
                           } else {
                               recurrenceEndOption = .never
                           }
                       }
                   }
                   
                   // Initial conflict check
                   checkForTimeConflicts()
               }
               .alert(isPresented: $showingConflictAlert) {
                   Alert(
                       title: Text("Time Conflict"),
                       message: Text("This activity conflicts with another activity on your schedule. Would you like to save it anyway?"),
                       primaryButton: .default(Text("Save Anyway")) {
                           saveActivity()
                           presentationMode.wrappedValue.dismiss()
                       },
                       secondaryButton: .cancel()
                   )
               }
           }
       }
       
       private func checkForTimeConflicts() {
           if let activity = activity {
               // When editing, exclude the current activity from the check
               hasTimeConflict = viewModel.checkTimeConflict(start: startDate, end: endDate, excluding: activity.id)
           } else {
               // When creating, check against all activities
               hasTimeConflict = viewModel.checkTimeConflict(start: startDate, end: endDate)
           }
       }
       
       private func frequencyLabel(_ frequency: RecurrenceRule.Frequency, _ interval: Int) -> String {
           let plural = interval > 1
           
           switch frequency {
           case .daily:
               return plural ? "days" : "day"
           case .weekly:
               return plural ? "weeks" : "week"
           case .monthly:
               return plural ? "months" : "month"
           case .yearly:
               return plural ? "years" : "year"
           }
       }
       
       private func saveActivity() {
           // Create recurrence rule if needed
           var recurrenceRule: RecurrenceRule?
           if isRecurring {
               var endDate: Date?
               var occurrences: Int?
               
               switch recurrenceEndOption {
               case .onDate:
                   endDate = recurrenceEndDate
               case .afterOccurrences:
                   occurrences = recurrenceOccurrences
               case .never:
                   // Both remain nil
                   break
               }
               
               recurrenceRule = RecurrenceRule(
                   frequency: recurrenceFrequency,
                   interval: recurrenceInterval,
                   daysOfWeek: recurrenceFrequency == .weekly ? selectedDaysOfWeek : nil,
                   endDate: endDate,
                   occurrences: occurrences
               )
           }
           
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
                   notes: notes.isEmpty ? nil : notes,
                   enableReminders: enableNotifications,
                   reminderMinutesBefore: reminderTime,
                   recurrenceRule: recurrenceRule,
                   recurringParentId: activity.recurringParentId
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
                   notes: notes.isEmpty ? nil : notes,
                   enableReminders: enableNotifications,
                   reminderMinutesBefore: reminderTime,
                   recurrenceRule: recurrenceRule
               )
               
               viewModel.addActivity(newActivity)
           }
       }
    }
