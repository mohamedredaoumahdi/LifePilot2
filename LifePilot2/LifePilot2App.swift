import SwiftUI
import Firebase
import Combine
import FirebaseAuth

@main
struct LifePilotApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var forceRefresh = false
    private static var firebaseConfigured = false

    init() {
        // Configure Firebase properly for SwiftUI App lifecycle
        configureFirebase()
        
        // Verify Firebase configuration
        FirebaseConfigCheck.verifySetup()
        
        // Verify current user token is still valid
        verifyAuthToken()
        
        // Check if onboarding needs to be shown
        checkOnboardingStatus()
    }
    
    private func verifyAuthToken() {
        // Only attempt verification if there's a current user
        if let currentUser = Auth.auth().currentUser {
            print("Verifying token for user: \(currentUser.email ?? "unknown")")
            
            // Get a new ID token to verify with the server
            currentUser.getIDTokenForcingRefresh(true) { (idToken, error) in
                if let error = error {
                    print("❌ Token refresh failed, user may have been deleted: \(error.localizedDescription)")
                    
                    // Handle specific error cases
                    let nsError = error as NSError
                    if nsError.code == 17011 { // User record doesn't exist
                        print("User account has been deleted from server")
                        // Force sign out
                        try? Auth.auth().signOut()
                        
                        // Clear any cached user data
                        UserDefaults.standard.removeObject(forKey: "currentUser")
                        
                        // Post notification to update UI
                        NotificationCenter.default.post(name: NSNotification.Name("UserAccountDeleted"), object: nil)
                    } else {
                        // Other token errors
                        print("Token verification failed with code: \(nsError.code)")
                    }
                } else if let token = idToken {
                    print("✅ Token verified successfully")
                    // Optionally, you could use this token for other API calls
                }
            }
        }
    }
    
    private func configureFirebase() {
        // Only configure Firebase if it hasn't been configured already
        if !Self.firebaseConfigured && FirebaseApp.app() == nil {
            FirebaseApp.configure()
            Self.firebaseConfigured = true
            print("Firebase configured in app initialization")
        } else {
            print("Firebase was already configured")
        }
        
        // Log authentication state for debugging
        if let user = Auth.auth().currentUser {
            print("Already logged in user: \(user.email ?? "unknown"), UID: \(user.uid)")
        } else {
            print("No user is currently logged in")
        }
    }
    
    private func checkOnboardingStatus() {
        // Only check if onboarding is completed if we have a saved value
        if UserDefaults.standard.object(forKey: "hasCompletedOnboarding") == nil {
            // First-time user, make sure onboarding is shown
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }
    
    var body: some Scene {
        WindowGroup {
                // Debug logs
                let _ = print("hasCompletedOnboarding: \(hasCompletedOnboarding)")
                let _ = print("authState: \(authViewModel.authState)")
                
                Group {
                    if authViewModel.authState == .initializing {
                        LoadingView(message: "Starting LifePilot...")
                    } else if !authViewModel.authState.isAuthenticated {
                        // Show auth view when not authenticated, regardless of onboarding status
                        AuthView()
                            .environmentObject(authViewModel)
                    } else if !hasCompletedOnboarding {
                        // ONLY check UserDefaults for onboarding status, IGNORE profile flag
                        OnboardingView()
                            .environmentObject(authViewModel)
                    } else {
                        // Show main app when authenticated and UserDefaults says onboarding completed
                        MainAppView()
                            .environmentObject(authViewModel)
                    }
                }
                .animation(.spring(), value: authViewModel.authState)
                .animation(.spring(), value: hasCompletedOnboarding)
            }
    }
}

// Loading view
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}



// MARK: - Main App View
struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        if authViewModel.currentUser == nil {
            // Show a loading view while waiting for the profile
            ProgressView("Loading profile...")
                .onAppear {
                    print("MainAppView: waiting for user profile")
                }
        } else {
            // Regular tab view
            TabView {
                NavigationView {
                    PersonalizedAnalysisView()
                }
                .tabItem {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("Insights")
                }
                
                NavigationView {
                    WeeklyScheduleView()
                }
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
                
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
        }
    }
}
