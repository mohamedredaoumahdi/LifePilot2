import SwiftUI

struct InsightCardView: View {
    let insight: Insight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Severity indicator
                severityIndicator(severity: insight.severity)
                
                Text(insight.title)
                    .font(.headline)
                
                Spacer()
                
                // Focus area badge
                FocusAreaBadge(focusArea: insight.focusArea)
            }
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func severityIndicator(severity: InsightSeverity) -> some View {
        let color: Color
        let iconName: String
        
        switch severity {
        case .positive:
            color = .green
            iconName = "checkmark.circle.fill"
        case .neutral:
            color = .blue
            iconName = "info.circle.fill"
        case .needsAttention:
            color = .orange
            iconName = "exclamationmark.triangle.fill"
        case .critical:
            color = .red
            iconName = "xmark.octagon.fill"
        }
        
        return Image(systemName: iconName)
            .foregroundColor(color)
    }
}

struct FocusAreaBadge: View {
    let focusArea: FocusArea
    
    var body: some View {
        Text(focusArea.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var color: Color {
        switch focusArea {
        case .health:
            return .green
        case .productivity:
            return .blue
        case .career:
            return .purple
        case .relationships:
            return .pink
        case .learning:
            return .orange
        case .mindfulness:
            return .indigo
        case .finance:
            return .yellow
        case .creativity:
            return .red
        }
    }
}

struct InsightCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            InsightCardView(insight: Insight(
                title: "Morning Routine Needs Structure",
                description: "Your current morning routine lacks consistency which can impact your overall productivity throughout the day.",
                focusArea: .productivity,
                severity: .needsAttention
            ))
            
            InsightCardView(insight: Insight(
                title: "Good Sleep Hygiene",
                description: "Your sleep schedule is consistent and aligns well with your night owl tendencies.",
                focusArea: .health,
                severity: .positive
            ))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
