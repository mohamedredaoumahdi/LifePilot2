import SwiftUI

struct OnboardingView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showMainApp = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                progressView
                
                // Main content based on current step
                stepContent
                
                // Navigation buttons
                navigationButtons
            }
            .padding()
            .navigationTitle(coordinator.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: Binding<Bool>(
                get: { coordinator.error != nil },
                set: { if !$0 { coordinator.error = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(coordinator.error ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $showMainApp) {
                // Main app after completing onboarding
                TabView {
                    NavigationView {
                        PersonalizedAnalysisView()
                            .environmentObject(authViewModel)
                    }
                    .tabItem {
                        Image(systemName: "chart.bar.doc.horizontal")
                        Text("Insights")
                    }
                    
                    NavigationView {
                        WeeklyScheduleView()
                            .environmentObject(authViewModel)
                    }
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Schedule")
                    }
                    
                    NavigationView {
                        SettingsView()
                            .environmentObject(authViewModel)
                    }
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
            }
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        let totalSteps = OnboardingStep.allCases.count - 1 // Exclude .complete
        let currentStepNumber = min(coordinator.currentStep.rawValue + 1, totalSteps)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(currentStepNumber) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(coordinator.currentStep.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(coordinator.currentStep.rawValue), total: Double(totalSteps - 1))
                .accentColor(.blue)
        }
        .padding(.vertical)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch coordinator.currentStep {
                case .welcome:
                    welcomeStepView
                case .personalityQuestions:
                    personalityQuestionsView
                case .lifestyleQuestions:
                    lifestyleQuestionsView
                case .goalsQuestions:
                    goalsQuestionsView
                case .profileSummary:
                    profileSummaryView
                case .confirmation:
                    confirmationView
                case .complete:
                    completeView
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStepView: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
            
            Text("Welcome to LifePilot")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Your personal life transformation coach")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("LifePilot will help you build personalized routines and habits that align with your goals and lifestyle. Let's start by getting to know you a bit better.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.top)
            
            Text("The following steps will ask about your personality, current lifestyle, and goals. This information will help us create recommendations tailored just for you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Personality Questions Step
    
    private var personalityQuestionsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Let's start with your sleep preferences")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Are you a night owl or an early bird?")
                    .font(.subheadline)
                
                ForEach(SleepPreference.allCases, id: \.self) { preference in
                    Button(action: {
                        coordinator.updateSleepPreference(preference)
                    }) {
                        HStack {
                            Text(preference.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if coordinator.userProfile.sleepPreference == preference {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(coordinator.userProfile.sleepPreference == preference ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Personality type")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Which of these best describes you?")
                    .font(.subheadline)
                
                ForEach(["Achiever", "Analyzer", "Creator", "Helper"], id: \.self) { type in
                    Button(action: {
                        coordinator.updatePersonalityType(type)
                    }) {
                        HStack {
                            Text(type)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if coordinator.userProfile.personalityType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(coordinator.userProfile.personalityType == type ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Lifestyle Questions Step
    
    private var lifestyleQuestionsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your current activity level")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How would you describe your physical activity?")
                    .font(.subheadline)
                
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button(action: {
                        coordinator.updateActivityLevel(level)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.rawValue)
                                    .foregroundColor(.primary)
                                
                                Text(activityLevelDescription(level))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if coordinator.userProfile.activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(coordinator.userProfile.activityLevel == level ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Current challenges")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select all the areas where you face challenges:")
                    .font(.subheadline)
                
                ForEach(Challenge.allCases, id: \.self) { challenge in
                    Button(action: {
                        coordinator.toggleChallenge(challenge)
                    }) {
                        HStack {
                            Text(challenge.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if coordinator.userProfile.currentChallenges.contains(challenge) {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "square")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(coordinator.userProfile.currentChallenges.contains(challenge) ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // Helper function for activity level descriptions
    private func activityLevelDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "Little to no regular exercise, desk job"
        case .light:
            return "Light exercise 1-3 days per week"
        case .moderate:
            return "Moderate exercise 3-5 days per week"
        case .active:
            return "Active exercise 6-7 days per week"
        case .veryActive:
            return "Very active exercise, physical job or training twice daily"
        }
    }
    
    // MARK: - Goals Questions Step
    
    private var goalsQuestionsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Areas you'd like to focus on")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select all areas where you'd like to see improvement:")
                    .font(.subheadline)
                
                ForEach(FocusArea.allCases, id: \.self) { area in
                    Button(action: {
                        coordinator.toggleFocusArea(area)
                    }) {
                        HStack {
                            Text(area.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if coordinator.userProfile.focusAreas.contains(area) {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "square")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(coordinator.userProfile.focusAreas.contains(area) ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Profile Summary Step
    
    private var profileSummaryView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Here's what we've learned about you")
                .font(.headline)
            
            Text(coordinator.generateProfileSummary())
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            
            Text("Does this summary accurately reflect your situation?")
                .font(.subheadline)
                .padding(.top)
            
            Text("If not, you can go back and adjust your responses.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Confirmation Step
    
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Ready to get started?")
                .font(.headline)
            
            Text("Based on your profile, we'll create personalized recommendations to help you achieve your goals.")
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What happens next:")
                    .font(.subheadline)
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Generate insights")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("We'll analyze your profile to identify key insights about your current habits and lifestyle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Create recommendations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("We'll suggest personalized habit changes and routines that align with your goals.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Build your weekly schedule")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Accept the recommendations you like, and we'll integrate them into your weekly schedule.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Complete Step
    
    // Update the "Continue to LifePilot" button in completeView
    private var completeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding()
            
            Text("You're all set!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your profile has been created successfully")
                .font(.title3)
                .foregroundColor(.secondary)
            
            if coordinator.isLoading || coordinator.isGeneratingAnalysis {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text(coordinator.isGeneratingAnalysis ?
                         "Generating your personalized insights..." :
                         "Setting up your profile...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
            } else {
                Button(action: {
                    // Start the process with improved handling
                    coordinator.completeOnboardingAndGenerateAnalysis()
                    
                    // Listen for completion events
                    listenForAnalysisCompletion()
                }) {
                    Text("Continue to LifePilot")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
        }
        .padding()
    }
    
    private func listenForAnalysisCompletion() {
        // Set the flag FIRST, before any notifications
        print("Setting hasCompletedOnboarding = true in UserDefaults")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Create a cancellable publisher for the analysis generation status
        let generationSubscription = coordinator.$isGeneratingAnalysis
            .dropFirst() // Skip the initial value
            .sink { isGenerating in
                if !isGenerating && !coordinator.isLoading {
                    print("Analysis generation completed, proceeding to main app")
                    // Flag is already set, just transition
                    showMainApp = true
                }
            }
        
        // Add a very long fallback timeout just to prevent getting completely stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 300.0) {
            print("Emergency fallback timeout reached after 5 minutes, proceeding to main app")
            // Transition (flag is already set)
            showMainApp = true
        }
    }
    
    // Helper method to check analysis generation progress
    private func checkAndProceed() {
        if !coordinator.isGeneratingAnalysis && !coordinator.isLoading {
            // Analysis is complete, save state and show main app
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            showMainApp = true
        } else {
            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkAndProceed()
            }
        }
    }
    
    // Function to generate initial analysis
    private func generateInitialAnalysis() {
        // Get user ID directly - no need for guard let since it's not optional
        let userId = coordinator.userProfile.id
        
        // Create analysis view model
        let analysisViewModel = PersonalizedAnalysisViewModel()
        
        // Set the user ID
        analysisViewModel.setUserId(userId)
        
        // Generate analysis
        analysisViewModel.generateAnalysis()
        
        print("Initial analysis generation started for user: \(userId)")
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            // Back button (hidden on first step and completed step)
            if coordinator.currentStep != .welcome && coordinator.currentStep != .complete {
                Button(action: {
                    coordinator.moveToPreviousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
            } else {
                Spacer()
            }
            
            Spacer()
            
            // Next/Continue button (hidden on completed step)
            if coordinator.currentStep != .complete {
                Button(action: {
                    coordinator.moveToNextStep()
                }) {
                    HStack {
                        Text(coordinator.currentStep == .confirmation ? "Complete" : "Continue")
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(coordinator.isLoading)
            }
        }
        .padding()
    }
}

// MARK: - Main App Placeholder
struct MainAppPlaceholderView: View {
    var body: some View {
        TabView {
            NavigationView {
                PersonalizedAnalysisView()
            }
            .tabItem {
                Image(systemName: "chart.bar.doc.horizontal")
                Text("Insights")
            }
            
            Text("Weekly Schedule")
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
            
            Text("Settings")
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
