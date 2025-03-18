import Foundation
import Combine

class PersonalizedAnalysisViewModel: ObservableObject {
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var error: String?
    @Published var analysis: PersonalizedAnalysis?
    @Published var userProfile: UserProfile?
    
    // Services
    private let cohereService: CohereServiceProtocol
    private let databaseService: FirebaseDatabaseServiceProtocol
    private let authService: FirebaseAuthServiceProtocol
    
    // Store the user ID separately to avoid issues with optional bindings
    private var userId: String?
    
    // Cancellables for Combine
    var cancellables = Set<AnyCancellable>()
    
    // Initialize with dependencies
    init(cohereService: CohereServiceProtocol = CohereService(),
         databaseService: FirebaseDatabaseServiceProtocol = FirebaseDatabaseService(),
         authService: FirebaseAuthServiceProtocol = FirebaseAuthService()) {
        self.cohereService = cohereService
        self.databaseService = databaseService
        self.authService = authService
        
        // Subscribe to current user updates
        authService.currentUser
            .sink { [weak self] user in
                self?.userProfile = user
                if let userId = user?.id {
                    self?.userId = userId
                    print("PersonalizedAnalysisViewModel received user ID: \(userId)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Set the user ID explicitly (used when passing from view)
    func setUserId(_ id: String) {
        print("Setting user ID in ViewModel: \(id)")
        self.userId = id
    }
    
    // Update the generateAnalysis method in PersonalizedAnalysisViewModel.swift
    func generateAnalysis() {
        // Check if profile is available
        guard let userId = self.userId else {
            self.error = "User ID not available"
            print("❌ Cannot generate analysis: User ID not available")
            return
        }
        
        // First, check if there is already an analysis for this user
        self.isLoading = true
        self.error = nil
        
        print("Checking for existing analysis before generating new one for user: \(userId)")
        
        // First try to fetch existing analysis
        databaseService.getAnalysis(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Error checking for existing analysis: \(error) - will try to generate new one")
                        // If there was an error fetching, proceed with generation
                        self?.proceedWithGeneratingAnalysis()
                    }
                },
                receiveValue: { [weak self] existingAnalysis in
                    if let analysis = existingAnalysis {
                        // Analysis already exists, use it
                        print("Using existing analysis from database")
                        self?.analysis = analysis
                        self?.isLoading = false
                    } else {
                        // No existing analysis, generate a new one
                        print("No existing analysis found, generating new one")
                        self?.proceedWithGeneratingAnalysis()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // New helper method for analysis generation
    private func proceedWithGeneratingAnalysis() {
        // Get user profile to use for generation
        guard let userProfile = userProfile, let userId = self.userId else {
            self.error = "User profile not available"
            self.isLoading = false
            print("❌ Cannot generate analysis: User profile not available")
            return
        }
        
        print("Generating analysis for user ID: \(userId)")
        
        // Check if we need to use default focus areas
        var profileToUse = userProfile
        if profileToUse.focusAreas.isEmpty {
            print("Using default focus areas since user hasn't selected any")
            profileToUse = createProfileWithDefaultFocusAreas(from: userProfile)
        }
        
        // Generate analysis using Cohere API
        cohereService.generateAnalysis(for: profileToUse)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = "Error generating analysis: \(error.localizedDescription)"
                        print("❌ Error generating analysis: \(error)")
                    }
                },
                receiveValue: { [weak self] responseText in
                    guard let self = self else { return }
                    
                    // Parse the response
                    if let parsedAnalysis = AnalysisParser.parseAnalysisResponse(responseText) {
                        // Create a proper analysis with the current user ID
                        var analysis = parsedAnalysis
                        analysis.userId = userId
                        
                        // Update the view model
                        self.analysis = analysis
                        print("✅ Successfully generated and parsed analysis")
                        
                        // Save to Firebase
                        self.saveAnalysisToDatabase(analysis)
                    } else {
                        self.error = "Failed to parse analysis response"
                        print("❌ Failed to parse analysis response")
                    }
                }
            )
            .store(in: &cancellables)
    }
    /// Create a copy of the user profile with default focus areas
    private func createProfileWithDefaultFocusAreas(from profile: UserProfile) -> UserProfile {
        // Create a copy with default focus areas for more meaningful analysis
        return UserProfile(
            id: profile.id,
            name: profile.name,
            email: profile.email,
            createdAt: profile.createdAt,
            personalityType: profile.personalityType,
            onboardingCompleted: profile.onboardingCompleted,
            sleepPreference: profile.sleepPreference,
            activityLevel: profile.activityLevel,
            focusAreas: [.health, .productivity, .mindfulness], // Default focus areas
            currentChallenges: profile.currentChallenges.isEmpty ?
                [.timeManagement, .motivation] : profile.currentChallenges // Default challenges if empty
        )
    }
    
    /// Save user's response to recommendations (accept/reject)
    func updateRecommendationStatus(recommendationId: String, accepted: Bool) {
        guard var analysis = analysis else { return }
        
        // Find and update the recommendation
        if let index = analysis.recommendations.firstIndex(where: { $0.id == recommendationId }) {
            analysis.recommendations[index].accepted = accepted
            
            // Update local state
            self.analysis = analysis
            
            // Save to database
            saveAnalysisToDatabase(analysis)
        }
    }
    
    /// Fetch existing analysis from the database
    func fetchExistingAnalysis() {
        guard let userId = self.userId else {
            self.error = "User ID not available"
            print("Cannot fetch analysis: User ID not available")
            return
        }
        
        print("Fetching analysis for user ID: \(userId)")
        self.isLoading = true
        self.error = nil
        
        databaseService.getAnalysis(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = "Error fetching analysis: \(error.localizedDescription)"
                        print("Error fetching analysis: \(error)")
                    }
                },
                receiveValue: { [weak self] analysis in
                    if let analysis = analysis {
                        print("Successfully fetched analysis with \(analysis.insights.count) insights")
                        self?.analysis = analysis
                    } else {
                        print("No analysis found for user")
                        self?.analysis = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func saveAnalysisToDatabase(_ analysis: PersonalizedAnalysis) {
        print("Saving analysis to database for user ID: \(analysis.userId)")
        databaseService.saveAnalysis(analysis)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Error saving analysis: \(error.localizedDescription)"
                        print("Error saving analysis: \(error)")
                    } else {
                        print("Analysis saved successfully")
                    }
                },
                receiveValue: { _ in
                    // Successfully saved
                }
            )
            .store(in: &cancellables)
    }
    
    // Get a subset of insights filtered by focus area
    func insightsForFocusArea(_ focusArea: FocusArea) -> [Insight] {
        guard let analysis = analysis else { return [] }
        return analysis.insights.filter { $0.focusArea == focusArea }
    }
    
    // Get recommendations filtered by focus area
    func recommendationsForFocusArea(_ focusArea: FocusArea) -> [Recommendation] {
        guard let analysis = analysis else { return [] }
        return analysis.recommendations.filter { $0.focusArea == focusArea }
    }
    
    // Get all accepted recommendations
    func acceptedRecommendations() -> [Recommendation] {
        guard let analysis = analysis else { return [] }
        return analysis.recommendations.filter { $0.accepted == true }
    }
    
    // Get all recommendations that haven't been acted upon
    func pendingRecommendations() -> [Recommendation] {
        guard let analysis = analysis else { return [] }
        return analysis.recommendations.filter { $0.accepted == nil }
    }
    
    /// Set the user profile explicitly (used when passing from coordinator)
    func setUserProfile(_ profile: UserProfile) {
        print("Setting user profile in ViewModel: \(profile.id)")
        self.userProfile = profile
        self.userId = profile.id
    }
}
