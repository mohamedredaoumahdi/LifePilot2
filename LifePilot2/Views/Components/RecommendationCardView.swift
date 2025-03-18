import SwiftUI

struct RecommendationCardView: View {
    let recommendation: Recommendation
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recommendation.title)
                    .font(.headline)
                
                Spacer()
                
                // Impact badge
                ImpactBadge(impact: recommendation.impact)
            }
            
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                // Focus area badge
                FocusAreaBadge(focusArea: recommendation.focusArea)
                
                // Timeframe badge
                TimeframeBadge(timeframe: recommendation.timeframe)
                
                Spacer()
                
                // Accept/Reject buttons
                if recommendation.accepted == nil {
                    HStack(spacing: 8) {
                        Button(action: onReject) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        
                        Button(action: onAccept) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                } else if recommendation.accepted == true {
                    Label("Accepted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Label("Declined", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ImpactBadge: View {
    let impact: RecommendationImpact
    
    var body: some View {
        Text(impact.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var color: Color {
        switch impact {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

struct TimeframeBadge: View {
    let timeframe: TimeFrame
    
    var body: some View {
        Text(timeframe.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.gray)
            .cornerRadius(8)
    }
}

struct RecommendationCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RecommendationCardView(
                recommendation: Recommendation(
                    title: "Start with 5-Minute Morning Meditation",
                    description: "Begin each day with a short mindfulness session to improve focus and reduce stress throughout the day.",
                    focusArea: .mindfulness,
                    impact: .high,
                    timeframe: .immediate,
                    accepted: nil
                ),
                onAccept: {},
                onReject: {}
            )
            
            RecommendationCardView(
                recommendation: Recommendation(
                    title: "Track Water Intake",
                    description: "Use an app or journal to track your daily water consumption, aiming for 8 glasses per day.",
                    focusArea: .health,
                    impact: .medium,
                    timeframe: .shortTerm,
                    accepted: true
                ),
                onAccept: {},
                onReject: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
