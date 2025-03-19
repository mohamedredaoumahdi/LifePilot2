import Foundation
import SwiftUI

struct ActivityStatisticsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: WeeklyScheduleViewModel
    
    @State private var selectedTimeRange: TimeRangeOption = .week
    @State private var showingAllActivities = false
    
    private var statistics: ActivityStats {
        viewModel.getActivityStatistics(for: selectedTimeRange)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Time Range")) {
                    Picker("View Statistics For", selection: $selectedTimeRange) {
                        Text("Current Week").tag(TimeRangeOption.week)
                        Text("Current Month").tag(TimeRangeOption.month)
                        Text("All Time").tag(TimeRangeOption.allTime)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Completion Rate")) {
                    CompletionRateView(statistics: statistics)
                }
                
                Section(header: Text("Activity Types")) {
                    ActivityTypesBreakdownView(statistics: statistics)
                }
                
                Section(header: Text("Time Allocation")) {
                    TimeAllocationView(statistics: statistics)
                }
                
                Section(header: Text("Activity List")) {
                    if statistics.activities.isEmpty {
                        Text("No activities in this time range")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(showingAllActivities ? statistics.activities : Array(statistics.activities.prefix(5))) { activity in
                            ActivityListRow(activity: activity)
                        }
                        
                        if statistics.activities.count > 5 && !showingAllActivities {
                            Button(action: {
                                showingAllActivities = true
                            }) {
                                Text("Show All (\(statistics.activities.count)) Activities")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Completion Rate View

struct CompletionRateView: View {
    let statistics: ActivityStats
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom) {
                Text("\(Int(statistics.completionRate * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(completionColor)
                
                Text("completion rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 8)
                    .opacity(0.2)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: CGFloat(statistics.completionRate) * (UIScreen.main.bounds.width - 40), height: 8)
                    .foregroundColor(completionColor)
            }
            .cornerRadius(4)
            
            // Completion details
            HStack {
                VStack {
                    Text("\(statistics.completedCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(statistics.pendingCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(statistics.totalCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var completionColor: Color {
        let rate = statistics.completionRate
        
        if rate >= 0.8 {
            return .green
        } else if rate >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Activity Types Breakdown View

struct ActivityTypesBreakdownView: View {
    let statistics: ActivityStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Activity type breakdown
            ForEach(statistics.activityTypeCounts.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                HStack {
                    Text(type.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(height: 8)
                        .opacity(0.2)
                        .foregroundColor(.gray)
                    
                    Rectangle()
                        .frame(width: CGFloat(count) / CGFloat(statistics.totalCount) * (UIScreen.main.bounds.width - 40), height: 8)
                        .foregroundColor(colorForActivityType(type))
                }
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func colorForActivityType(_ type: ActivityType) -> Color {
        switch type {
        case .task:
            return .blue
        case .habit:
            return .green
        case .exercise:
            return .orange
        case .meal:
            return .purple
        case .work:
            return .gray
        case .leisure:
            return .pink
        case .learning:
            return .yellow
        case .mindfulness:
            return .teal
        case .sleep:
            return .indigo
        }
    }
}

// MARK: - Time Allocation View

struct TimeAllocationView: View {
    let statistics: ActivityStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Check if we have any activities with duration
            if statistics.totalDuration > 0 {
                HStack {
                    Text("Total Time")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(formatDuration(statistics.totalDuration))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Duration by activity type
                ForEach(statistics.activityTypeDurations.sorted(by: { $0.value > $1.value }), id: \.key) { type, duration in
                    VStack(spacing: 8) {
                        HStack {
                            Text(type.rawValue)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(formatDuration(duration))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        // Progress bar
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(height: 8)
                                .opacity(0.2)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: CGFloat(duration) / CGFloat(statistics.totalDuration) * (UIScreen.main.bounds.width - 40), height: 8)
                                .foregroundColor(colorForActivityType(type))
                        }
                        .cornerRadius(4)
                    }
                }
            } else {
                Text("No activities with duration data")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func colorForActivityType(_ type: ActivityType) -> Color {
        switch type {
        case .task:
            return .blue
        case .habit:
            return .green
        case .exercise:
            return .orange
        case .meal:
            return .purple
        case .work:
            return .gray
        case .leisure:
            return .pink
        case .learning:
            return .yellow
        case .mindfulness:
            return .teal
        case .sleep:
            return .indigo
        }
    }
}

// MARK: - Activity List Row

struct ActivityListRow: View {
    let activity: ScheduledActivity
    
    var body: some View {
        HStack {
            // Activity status indicator
            Circle()
                .fill(activity.isCompleted ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                
                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Activity type badge
            Text(activity.activityType.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(activityColor.opacity(0.2))
                .foregroundColor(activityColor)
                .cornerRadius(8)
        }
    }
    
    private var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        
        return formatter.string(from: activity.startTime)
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

// MARK: - Supporting Types

enum TimeRangeOption {
    case week
    case month
    case allTime
}

struct ActivityStats {
    let completedCount: Int
    let pendingCount: Int
    let totalCount: Int
    let completionRate: Double
    
    let activityTypeCounts: [ActivityType: Int]
    let activityTypeDurations: [ActivityType: TimeInterval]
    let totalDuration: TimeInterval
    
    let activities: [ScheduledActivity]
}
