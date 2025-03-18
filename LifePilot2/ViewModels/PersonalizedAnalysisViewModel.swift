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
    private var cancellables = Set<AnyCancellable>()
    private var analysisSubscription: AnyCancellable?
    
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
                    AppConfig.Debug.log("PersonalizedAnalysisViewModel received user ID: \(userId)")
                    
                    // Set up a real-time listener for analysis updates
                    self?.setupAnalysisListener(userId: userId)
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        analysisSubscription?.cancel()
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Public Methods
    
    /// Set the user ID explicitly (used when passing from view)
    func setUserId(_ id: String) {
        AppConfig.Debug.log("Setting user ID in ViewModel: \(id)")
        self.userId = id
        
        // Set up a real-time listener for analysis updates
        setupAnalysisListener(userId: id)
    }
    
    /// Set up a real-time listener for analysis updates
    private func setupAnalysisListener(userId: String) {
        // Cancel any existing subscription
        analysisSubscription?.cancel()
        
        // Set up a new subscription
        analysisSubscription = databaseService.observeAnalysis(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Error observing analysis: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error observing analysis: \(error)")
                    }
                },
                receiveValue: { [weak self] analysis in
                    self?.analysis = analysis
                    if analysis != nil {
                        AppConfig.Debug.success("Real-time analysis update received")
                        // Clear the loading state and error if we receive an analysis
                        self?.isLoading = false
                        self?.error = nil
                    }
                }
            )
    }
    
    // Generate a new analysis
    func generateAnalysis() {
        // Check if profile is available
        guard let userId = self.userId, let userProfile = userProfile else {
            self.error = "User profile not available"
            AppConfig.Debug.error("Cannot generate analysis: User profile not available")
            return
        }
        
        // Update UI state
        self.isLoading = true
        self.error = nil
        
        AppConfig.Debug.log("Generating analysis for user ID: \(userId)")
        
        // Check if we need to use default focus areas
        var profileToUse = userProfile
        if profileToUse.focusAreas.isEmpty {
            AppConfig.Debug.log("Using default focus areas since user hasn't selected any")
            profileToUse = createProfileWithDefaultFocusAreas(from: userProfile)
        }
        
        // Generate analysis using Cohere API
        cohereService.generateAnalysis(for: profileToUse)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.error = "Error generating analysis: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error generating analysis: \(error)")
                    }
                },
                receiveValue: { [weak self] responseText in
                    guard let self = self else { return }
                    
                    // Parse the response
                    if let parsedAnalysis = AnalysisParser.parseAnalysisResponse(responseText) {
                        // Create a proper analysis with the current user ID
                        var analysis = parsedAnalysis
                        analysis.userId = userId
                        
                        // Save to Firebase - this will trigger our listener
                        AppConfig.Debug.success("Successfully generated and parsed analysis, saving to Firebase")
                        self.saveAnalysisToDatabase(analysis)
                    } else {
                        self.error = "Failed to parse analysis response"
                        self.isLoading = false
                        AppConfig.Debug.error("Failed to parse analysis response")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Update a recommendation status (accept/reject)
    func updateRecommendationStatus(recommendationId: String, accepted: Bool) {
        guard var analysis = analysis else { return }
        
        // Find and update the recommendation
        if let index = analysis.recommendations.firstIndex(where: { $0.id == recommendationId }) {
            analysis.recommendations[index].accepted = accepted
            
            // Save to database - this will trigger our listener
            saveAnalysisToDatabase(analysis)
        }
    }
    
    /// Fetch existing analysis from the database (one-time fetch)
    func fetchExistingAnalysis() {
        guard let userId = self.userId else {
            self.error = "User ID not available"
            AppConfig.Debug.error("Cannot fetch analysis: User ID not available")
            return
        }
        
        AppConfig.Debug.log("Fetching analysis for user ID: \(userId)")
        self.isLoading = true
        self.error = nil
        
        databaseService.getAnalysis(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = "Error fetching analysis: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error fetching analysis: \(error)")
                    }
                },
                receiveValue: { [weak self] analysis in
                    if let analysis = analysis {
                        AppConfig.Debug.success("Successfully fetched analysis with \(analysis.insights.count) insights")
                        self?.analysis = analysis
                    } else {
                        AppConfig.Debug.log("No analysis found for user")
                        self?.analysis = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
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
    
    private func saveAnalysisToDatabase(_ analysis: PersonalizedAnalysis) {
        AppConfig.Debug.log("Saving analysis to database for user ID: \(analysis.userId)")
        databaseService.saveAnalysis(analysis)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = "Error saving analysis: \(error.localizedDescription)"
                        AppConfig.Debug.error("Error saving analysis: \(error)")
                    } else {
                        AppConfig.Debug.success("Analysis saved successfully to database")
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
        AppConfig.Debug.log("Setting user profile in ViewModel: \(profile.id)")
        self.userProfile = profile
        self.userId = profile.id
        
        // Set up a real-time listener for analysis updates
        setupAnalysisListener(userId: profile.id)
    }
}
