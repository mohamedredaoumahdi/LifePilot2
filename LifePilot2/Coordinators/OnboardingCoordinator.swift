import Foundation
import Combine

// MARK: - Onboarding Coordinator
class OnboardingCoordinator: ObservableObject {
    // Published properties
    @Published var currentStep: OnboardingStep = .welcome
    @Published var userProfile: UserProfile
    @Published var error: String?
    @Published var isLoading = false
    @Published var isGeneratingAnalysis = false
    
    // Services
    private let authService: FirebaseAuthServiceProtocol
    private let databaseService: FirebaseDatabaseServiceProtocol
    private var analysisViewModel: PersonalizedAnalysisViewModel?
    private var analysisTimeoutTimer: Timer?

    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Initialize with default or existing profile
    init(userProfile: UserProfile? = nil,
         authService: FirebaseAuthServiceProtocol = FirebaseAuthService(),
         databaseService: FirebaseDatabaseServiceProtocol = FirebaseDatabaseService()) {
        
        // If no profile is provided, create a default one
        self.userProfile = userProfile ?? UserProfile(
            name: "",
            email: "",
            sleepPreference: .neutral,
            activityLevel: .moderate,
            focusAreas: [],
            currentChallenges: []
        )
        
        self.authService = authService
        self.databaseService = databaseService
        
        // Subscribe to user profile updates
        authService.currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                // Update the user ID and email from auth service
                self?.userProfile.id = user.id
                self?.userProfile.email = user.email
            }
            .store(in: &cancellables)
    }
    
    deinit {
        analysisTimeoutTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Navigation Methods
    
    func moveToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        
        // Validate current step before moving to the next
        if validateCurrentStep() {
            self.currentStep = nextStep
        }
    }
    
    func moveToPreviousStep() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        
        self.currentStep = previousStep
    }
    
    func goToStep(_ step: OnboardingStep) {
        self.currentStep = step
    }
    
    // MARK: - Validation Methods
    
    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .welcome:
            // No validation needed for welcome
            return true
            
        case .personalityQuestions:
            // Ensure personality questions are answered
            if userProfile.personalityType == nil {
                self.error = "Please select a personality type before proceeding."
                return false
            }
            return true
            
        case .lifestyleQuestions:
            // Example validation: ensure activity level is set
            if userProfile.activityLevel == .moderate && userProfile.currentChallenges.isEmpty {
                self.error = "Please select your activity level and at least one challenge before proceeding."
                return false
            }
            return true
            
        case .goalsQuestions:
            // Ensure at least one focus area is selected
            if userProfile.focusAreas.isEmpty {
                self.error = "Please select at least one area you'd like to focus on."
                return false
            }
            return true
            
        case .profileSummary, .confirmation, .complete:
            // No validation needed for these steps
            return true
        }
    }
    
    // Enhanced completion method with analysis generation
    func completeOnboardingAndGenerateAnalysis() {
        isLoading = true
        error = nil
        
        // Mark onboarding as completed
        userProfile.onboardingCompleted = true
        
        // Save the user profile to Firebase FIRST
        databaseService.saveUserProfile(userProfile)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = "Failed to save profile: \(error.localizedDescription)"
                        AppConfig.Debug.error("Failed to save profile: \(error.localizedDescription)")
                        self?.isLoading = false
                    } else {
                        AppConfig.Debug.success("User profile saved with onboardingCompleted = true")
                        
                        // Set the onboarding flag in UserDefaults
                        UserDefaults.standard.set(true, forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
                        
                        // Now start analysis generation
                        self?.generateAnalysisAndWait()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    // Enhanced analysis generation with improved waiting
    private func generateAnalysisAndWait() {
        AppConfig.Debug.log("Starting initial analysis generation for user: \(userProfile.id)")
        isGeneratingAnalysis = true
        
        // Create a new ViewModel with retained reference
        let analysisVM = PersonalizedAnalysisViewModel()
        self.analysisViewModel = analysisVM
        
        // Set user ID and user profile explicitly
        analysisVM.setUserId(userProfile.id)
        analysisVM.setUserProfile(userProfile)
        
        // Set a timeout - proceed after 3 minutes even if analysis isn't complete
        analysisTimeoutTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.UI.analysisGenerationTimeout, repeats: false) { [weak self] _ in
            AppConfig.Debug.log("Analysis generation timeout reached - proceeding anyway")
            
            // Store the fact that generation was started but not confirmed complete
            UserDefaults.standard.set(true, forKey: AppConfig.App.UserDefaults.analysisGenerationInProgress)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConfig.App.UserDefaults.analysisGenerationStartTime)
            UserDefaults.standard.set(self?.userProfile.id, forKey: AppConfig.App.UserDefaults.pendingAnalysisUserId)
            
            // Cleanup
            self?.isGeneratingAnalysis = false
            self?.isLoading = false
            self?.analysisViewModel = nil
            self?.analysisTimeoutTimer = nil
            
            // Post notification that analysis is complete
            NotificationCenter.default.post(name: NSNotification.Name(AppConfig.App.Notifications.analysisComplete), object: nil)
        }
        
        // Generate analysis - this kicks off the API call
        analysisVM.generateAnalysis()
        
        // Monitor for completion
        Publishers.CombineLatest(analysisVM.$isLoading, analysisVM.$analysis)
            .sink { [weak self] (isLoading, analysis) in
                // Only consider complete when loading is false AND we have an analysis
                if !isLoading {
                    if analysis != nil {
                        AppConfig.Debug.success("Analysis generation successfully completed!")
                        guard let self = self else { return }
                        
                        // Make one final update to ensure the user profile is properly saved
                        self.userProfile.onboardingCompleted = true
                        self.databaseService.saveUserProfile(self.userProfile)
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        AppConfig.Debug.error("Failed to ensure onboardingCompleted flag: \(error)")
                                    } else {
                                        AppConfig.Debug.success("Confirmed user profile onboardingCompleted = true")
                                    }
                                    
                                    // Finalize completion
                                    self.isGeneratingAnalysis = false
                                    self.isLoading = false
                                    self.analysisViewModel = nil
                                    self.analysisTimeoutTimer?.invalidate()
                                    self.analysisTimeoutTimer = nil
                                    
                                    // Post notification that analysis is complete
                                    NotificationCenter.default.post(name: NSNotification.Name(AppConfig.App.Notifications.analysisComplete), object: nil)
                                },
                                receiveValue: { _ in }
                            )
                            .store(in: &self.cancellables)
                    } else {
                        AppConfig.Debug.log("Analysis loading complete but no analysis was generated")
                    }
                }
            }
            .store(in: &cancellables)
            
        // Also monitor for errors
        analysisVM.$error
            .compactMap { $0 } // Only proceed if there is an error
            .sink { [weak self] errorMessage in
                AppConfig.Debug.error("Analysis generation encountered an error: \(errorMessage)")
                self?.isGeneratingAnalysis = false
                self?.isLoading = false
                self?.analysisViewModel = nil
                // Invalidate timeout
                self?.analysisTimeoutTimer?.invalidate()
                self?.analysisTimeoutTimer = nil
                
                // Post notification that analysis is complete (even with error)
                NotificationCenter.default.post(name: NSNotification.Name(AppConfig.App.Notifications.analysisComplete), object: nil)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Methods
    
    // Update user's personality type
    func updatePersonalityType(_ type: String) {
        userProfile.personalityType = type
    }
    
    // Update sleep preference
    func updateSleepPreference(_ preference: SleepPreference) {
        userProfile.sleepPreference = preference
    }
    
    // Update activity level
    func updateActivityLevel(_ level: ActivityLevel) {
        userProfile.activityLevel = level
    }
    
    // Toggle a focus area (add if not present, remove if present)
    func toggleFocusArea(_ area: FocusArea) {
        if userProfile.focusAreas.contains(area) {
            userProfile.focusAreas.removeAll { $0 == area }
        } else {
            userProfile.focusAreas.append(area)
        }
    }
    
    // Toggle a challenge
    func toggleChallenge(_ challenge: Challenge) {
        if userProfile.currentChallenges.contains(challenge) {
            userProfile.currentChallenges.removeAll { $0 == challenge }
        } else {
            userProfile.currentChallenges.append(challenge)
        }
    }
    
    // Generate profile summary
    func generateProfileSummary() -> String {
        let sleepHabit = userProfile.sleepPreference.rawValue
        let activityLevel = userProfile.activityLevel.rawValue
        let personalityType = userProfile.personalityType ?? "Undefined"
        
        let focusAreas = userProfile.focusAreas.isEmpty ?
            "No specific focus areas selected" :
            userProfile.focusAreas.map { $0.rawValue }.joined(separator: ", ")
        
        let challenges = userProfile.currentChallenges.isEmpty ?
            "No specific challenges identified" :
            userProfile.currentChallenges.map { $0.rawValue }.joined(separator: ", ")
        
        return """
        Based on your responses, here's what we've learned about you:
        
        You identify as a \(personalityType) type who is a \(sleepHabit.lowercased()) with a \(activityLevel.lowercased()) activity level.
        
        You want to focus on: \(focusAreas).
        
        Your current challenges include: \(challenges).
        
        This profile will be used to generate personalized recommendations tailored specifically for you.
        """
    }
    
    // MARK: - Completion Methods
    
    private func completeOnboarding() {
        isLoading = true
        error = nil
        
        // Mark onboarding as completed
        userProfile.onboardingCompleted = true
        
        // Save the user profile to Firebase
        databaseService.saveUserProfile(userProfile)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = "Failed to save profile: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] _ in
                    // Successfully saved, set to complete
                    self?.currentStep = .complete
                    
                    // Set the flag in UserDefaults
                    UserDefaults.standard.set(true, forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case personalityQuestions
    case lifestyleQuestions
    case goalsQuestions
    case profileSummary
    case confirmation
    case complete
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to LifePilot"
        case .personalityQuestions:
            return "About You"
        case .lifestyleQuestions:
            return "Your Lifestyle"
        case .goalsQuestions:
            return "Your Goals"
        case .profileSummary:
            return "Profile Summary"
        case .confirmation:
            return "Confirmation"
        case .complete:
            return "All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Let's get started building your personalized life transformation plan."
        case .personalityQuestions:
            return "Tell us a bit about your personality and preferences."
        case .lifestyleQuestions:
            return "Help us understand your current lifestyle and habits."
        case .goalsQuestions:
            return "What areas of your life would you like to improve?"
        case .profileSummary:
            return "Here's what we've learned about you so far."
        case .confirmation:
            return "Please confirm that these changes align with your goals."
        case .complete:
            return "Your profile is set up and ready to go!"
        }
    }
}
