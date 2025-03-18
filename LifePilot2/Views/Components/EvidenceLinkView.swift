import SwiftUI

struct EvidenceLinkView: View {
    let evidence: EvidenceLink
    
    var body: some View {
        Link(destination: evidence.url) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(evidence.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Evidence type badge
                    EvidenceTypeBadge(type: evidence.type)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct EvidenceTypeBadge: View {
    let type: EvidenceType
    
    var body: some View {
        Text(type.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var color: Color {
        switch type {
        case .article:
            return .blue
        case .study:
            return .purple
        case .book:
            return .green
        case .video:
            return .red
        case .podcast:
            return .orange
        }
    }
}

struct EvidenceLinkView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EvidenceLinkView(evidence: EvidenceLink(
                title: "The Power of Morning Routines - Harvard Health",
                url: URL(string: "https://www.health.harvard.edu")!,
                type: .article
            ))
            
            EvidenceLinkView(evidence: EvidenceLink(
                title: "Effects of Mindfulness on Stress Reduction",
                url: URL(string: "https://www.example.com")!,
                type: .study
            ))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
