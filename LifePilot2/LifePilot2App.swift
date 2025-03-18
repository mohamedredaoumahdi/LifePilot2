import SwiftUI
import Firebase
import Combine
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Verify Firebase configuration
        FirebaseConfigCheck.verifySetup()
        
        return true
    }
}

@main
struct LifePilot2App: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @AppStorage(AppConfig.App.UserDefaults.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var forceRefresh = false
    
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
                    // Only check UserDefaults for onboarding status, not profile flag
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
            // Listen for analysis completion notifications
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(AppConfig.App.Notifications.analysisComplete))) { _ in
                print("Received AnalysisComplete notification, updating UI")
                // Make sure the onboarding flag is set
                hasCompletedOnboarding = true
                forceRefresh.toggle()
            }
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
