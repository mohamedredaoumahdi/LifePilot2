import SwiftUI
import Combine

struct PersonalizedAnalysisView: View {
    @StateObject private var viewModel = PersonalizedAnalysisViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var previousUserId: String? = nil
    @State private var navigateToOnboarding = false
    @State private var analysisGenerationAttempted = false
    
    var body: some View {
        VStack {
            headerView
            
            // Error banner if needed
            if showingError {
                errorBanner
            }
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(message: error)
            } else if let analysis = viewModel.analysis {
                analysisContentView(analysis: analysis)
            } else {
                emptyStateView
            }
        }
        .onAppear {
            print("PersonalizedAnalysisView appeared, authViewModel.currentUser: \(String(describing: authViewModel.currentUser))")
            
            // GET RID OF ALL ONBOARDING CHECKS
            // We're here, we should stay here!
            
            // Make sure we have a user ID before attempting to fetch analysis
            if let user = authViewModel.currentUser {
                let userId = user.id
                print("Setting user ID: \(userId)")
                viewModel.setUserId(userId)
                viewModel.setUserProfile(user)
                
                // First fetch existing analysis
                print("Fetching any existing analysis...")
                viewModel.fetchExistingAnalysis()
                previousUserId = userId
                
                // Set up a timer to check after a short delay (giving fetch time to complete)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Only generate if we're not loading and don't have analysis
                    if !viewModel.isLoading && viewModel.analysis == nil && !analysisGenerationAttempted {
                        print("No existing analysis found after delay. Auto-generating...")
                        analysisGenerationAttempted = true
                        viewModel.generateAnalysis()
                    } else {
                        print("Analysis status: loading=\(viewModel.isLoading), analysis=\(viewModel.analysis != nil), attempted=\(analysisGenerationAttempted)")
                    }
                }
            } else {
                showingError = true
                errorMessage = "Unable to access user profile. Please try signing out and back in."
            }
        }// Use onReceive to monitor changes in auth state
        // Use onReceive to monitor changes in auth state
        .onReceive(authViewModel.$currentUser) { newUser in
            print("Auth state changed, new user: \(String(describing: newUser))")
            
            // GET RID OF ONBOARDING CHECK HERE TOO
            
            // Check if user ID has changed
            let newUserId = newUser?.id
            if newUserId != previousUserId {
                if let userId = newUserId, let user = newUser {
                    print("User ID changed from \(String(describing: previousUserId)) to \(userId)")
                    viewModel.setUserId(userId)
                    viewModel.setUserProfile(user)
                    viewModel.fetchExistingAnalysis()
                    showingError = false
                    previousUserId = userId
                    analysisGenerationAttempted = false
                } else if previousUserId != nil {
                    // User has signed out
                    print("User signed out or user profile lost")
                    previousUserId = nil
                    showingError = true
                    errorMessage = "User profile not available. Please sign in again."
                }
            }
        }
        .navigationTitle("Your Analysis")
    }
    // Error banner for user ID issues
    private var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                showingError = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Insights")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Based on your profile, here's what LifePilot suggests for your journey.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Loading View
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            // Enhanced loading animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
            }
            
            Text("Analyzing your profile...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Our AI is generating personalized insights just for you. This may take up to 30 seconds.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Add a cancel button option after 10 seconds
            if analysisGenerationAttempted {
                Button(action: {
                    // Reset the view state
                    analysisGenerationAttempted = false
                    viewModel.error = nil
                    
                    // Try loading any existing content
                    if let user = authViewModel.currentUser {
                        viewModel.setUserId(user.id)
                        viewModel.setUserProfile(user)
                        viewModel.fetchExistingAnalysis()
                    }
                }) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Oops! Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // First try to load existing analysis
            Button(action: {
                // First check if an analysis exists in the database
                viewModel.fetchExistingAnalysis()
            }) {
                Text("Check for Existing Analysis")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            
            // Try generating a new analysis
            Button(action: {
                if let user = authViewModel.currentUser {
                    viewModel.setUserId(user.id)
                    viewModel.setUserProfile(user)
                    viewModel.generateAnalysis()
                    analysisGenerationAttempted = true
                } else {
                    showingError = true
                    errorMessage = "User profile not available. Please try signing out and back in."
                }
            }) {
                Text("Generate New Analysis")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
            
            // Sign out option as a fallback
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out and Try Again")
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    // MARK: - Empty State View
    private var emptyStateView: some View {
        let generationInProgress = UserDefaults.standard.bool(forKey: "analysisGenerationInProgress")
        let pendingUserId = UserDefaults.standard.string(forKey: "pendingAnalysisUserId")
        let matchesCurrentUser = pendingUserId == authViewModel.currentUser?.id
        let isInBackground = generationInProgress && matchesCurrentUser
        
        return VStack(spacing: 20) {
            Image(systemName: isInBackground ? "hourglass" : "lightbulb")
                .font(.system(size: 50))
                .foregroundColor(isInBackground ? .orange : .yellow)
            
            // Updated text based on generation status
            Text(isInBackground ? "Analysis In Progress" :
                 (analysisGenerationAttempted ? "Analysis in Progress" : "No Analysis Yet"))
                .font(.headline)
            
            Text(isInBackground ?
                 "Your analysis is being generated in the background. This might take a few minutes." :
                 (analysisGenerationAttempted ?
                  "Your analysis is being prepared. This might take a moment. Sometimes the process can encounter issues with the AI response format. You can retry if needed." :
                  "Generate your personalized analysis to get insights based on your profile."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Different button based on status
            if isInBackground {
                Button(action: {
                    viewModel.fetchExistingAnalysis()
                }) {
                    Text("Check for Analysis")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top)
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        if let user = authViewModel.currentUser {
                            viewModel.setUserId(user.id)
                            viewModel.setUserProfile(user)
                            viewModel.generateAnalysis()
                            analysisGenerationAttempted = true
                        } else {
                            showingError = true
                            errorMessage = "User profile not available. Please try signing out and back in."
                        }
                    }) {
                        Text("Generate Analysis")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    if analysisGenerationAttempted {
                        Button(action: {
                            // Refresh the view
                            analysisGenerationAttempted = false
                            viewModel.error = nil
                            
                            // Try loading again after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let user = authViewModel.currentUser {
                                    viewModel.setUserId(user.id)
                                    viewModel.setUserProfile(user)
                                    viewModel.fetchExistingAnalysis()
                                }
                            }
                        }) {
                            Text("Reset & Try Again")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // MARK: - Analysis Content View
    private func analysisContentView(analysis: PersonalizedAnalysis) -> some View {
        VStack(spacing: 0) {
            // Tab selection
            Picker("Content", selection: $selectedTab) {
                Text("Insights").tag(0)
                Text("Recommendations").tag(1)
                Text("Evidence").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            // Content based on selected tab
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case 0:
                        insightsTabView(insights: analysis.insights)
                    case 1:
                        recommendationsTabView(recommendations: analysis.recommendations)
                    case 2:
                        evidenceTabView(evidence: analysis.evidenceLinks ?? [])
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Insights Tab
    private func insightsTabView(insights: [Insight]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(insights) { insight in
                InsightCardView(insight: insight)
            }
            
            if insights.isEmpty {
                Text("No insights available.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // MARK: - Recommendations Tab
    private func recommendationsTabView(recommendations: [Recommendation]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(recommendations) { recommendation in
                RecommendationCardView(
                    recommendation: recommendation,
                    onAccept: {
                        viewModel.updateRecommendationStatus(
                            recommendationId: recommendation.id,
                            accepted: true
                        )
                    },
                    onReject: {
                        viewModel.updateRecommendationStatus(
                            recommendationId: recommendation.id,
                            accepted: false
                        )
                    }
                )
            }
            
            if recommendations.isEmpty {
                Text("No recommendations available.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // MARK: - Evidence Tab
    private func evidenceTabView(evidence: [EvidenceLink]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(evidence) { item in
                EvidenceLinkView(evidence: item)
            }
            
            if evidence.isEmpty {
                Text("No evidence links available.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
}
