import Foundation
import SwiftUI
import Combine
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .initializing
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var error: AuthError?
    
    private let authService: FirebaseAuthService
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: FirebaseAuthService = FirebaseAuthService()) {
        print("Initializing AuthViewModel")
        
        // Initialize the auth service first
        self.authService = authService
        
        // Check initial state
        checkInitialAuthState()
        
        // Set up subscription for auth state changes
        setupAuthStateSubscription()
        
        // Add notification observer for deleted accounts
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(AppConfig.App.Notifications.userAccountDeleted),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("Received notification that user account was deleted")
            self?.authState = .unauthenticated
            self?.isAuthenticated = false
            self?.currentUser = nil
            self?.error = .accountNotFound
        }
    }

    // Add deinit to remove observer
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.forEach { $0.cancel() }
    }
    
    private func checkInitialAuthState() {
        if Auth.auth().currentUser != nil {
            print("Firebase shows a user is logged in, updating state...")
            self.authState = .authenticated
            self.isAuthenticated = true
        } else {
            self.authState = .unauthenticated
            self.isAuthenticated = false
        }
    }
    
    private func setupAuthStateSubscription() {
        authService.currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                
                let oldState = self.authState
                
                if user != nil {
                    self.currentUser = user
                    self.authState = .authenticated
                    self.isAuthenticated = true
                } else {
                    self.currentUser = nil
                    self.authState = .unauthenticated
                    self.isAuthenticated = false
                }
                
                print("Auth state transition: \(oldState) -> \(self.authState)")
            }
            .store(in: &cancellables)
    }
    
    func signIn(email: String, password: String) {
        self.authState = .authenticating
        self.error = nil
        
        // Log the attempt
        print("Attempting to sign in with email: \(email)")
        
        authService.signIn(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let serviceError) = completion {
                        self?.authState = .unauthenticated
                        
                        // Map service errors to auth errors for the UI
                        switch serviceError {
                        case .authenticationError:
                            self?.error = .invalidCredentials
                        case .documentNotFound:
                            self?.error = .accountNotFound
                        case .fetchError:
                            self?.error = .networkError
                        default:
                            self?.error = .unknown(serviceError.localizedDescription)
                        }
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.authState = .authenticated
                    self?.isAuthenticated = true
                    
                    // Ensure onboarding flag is set correctly based on user profile
                    if user.onboardingCompleted {
                        UserDefaults.standard.set(true, forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
                    } else {
                        UserDefaults.standard.set(false, forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
                    }
                }
            )
            .store(in: &cancellables)
    }

    func signUp(email: String, password: String, name: String) {
        self.authState = .authenticating
        self.error = nil
        
        authService.signUp(email: email, password: password, name: name)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.authState = .unauthenticated
                        self?.isAuthenticated = false
                        
                        // Map service errors to auth errors for the UI
                        switch error {
                        case .authenticationError:
                            self?.error = .emailAlreadyInUse
                        case .fetchError:
                            self?.error = .networkError
                        default:
                            self?.error = .unknown(error.localizedDescription)
                        }
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.authState = .authenticated
                    self?.isAuthenticated = true
                    
                    // New users need to complete onboarding
                    UserDefaults.standard.set(false, forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
                }
            )
            .store(in: &cancellables)
    }
    
    func signOut() {
        self.authState = .authenticating // Show loading state during sign out
        self.error = nil
        
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let serviceError) = completion {
                        // If sign out fails, we remain in authenticated state
                        self?.authState = .authenticated
                        self?.isAuthenticated = true
                        self?.error = .unknown("Sign out failed: \(serviceError.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] _ in
                    // On successful sign out
                    self?.currentUser = nil
                    self?.authState = .unauthenticated
                    self?.isAuthenticated = false
                    
                    // Clear any cached data
                    self?.clearUserCache()
                }
            )
            .store(in: &cancellables)
    }

    // Helper method to clear any cached user data on sign out
    private func clearUserCache() {
        // Reset onboarding status to ensure clean state for next login
        UserDefaults.standard.removeObject(forKey: AppConfig.App.UserDefaults.hasCompletedOnboarding)
        
        // Cancel any pending analysis generation
        UserDefaults.standard.removeObject(forKey: AppConfig.App.UserDefaults.analysisGenerationInProgress)
        UserDefaults.standard.removeObject(forKey: AppConfig.App.UserDefaults.analysisGenerationStartTime)
        UserDefaults.standard.removeObject(forKey: AppConfig.App.UserDefaults.pendingAnalysisUserId)
        
        // Clear other cached data if needed
        print("User cache cleared during sign out")
    }
    
    func resetAuthState() {
        authService.resetAuthState()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error resetting auth state: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                // Update UI state
                DispatchQueue.main.async {
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                    self?.authState = .unauthenticated
                    
                    // Clear cached data
                    self?.clearUserCache()
                }
            })
            .store(in: &cancellables)
    }
}

// Auth state enum
enum AuthState: Equatable {
    case initializing
    case unauthenticated
    case authenticating
    case authenticated
    case error(String)
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
}

// Auth error enum
enum AuthError: Error, Identifiable {
    case invalidCredentials
    case networkError
    case accountNotFound
    case weakPassword
    case emailAlreadyInUse
    case unknown(String)
    
    var id: String {
        switch self {
        case .invalidCredentials: return "invalid_credentials"
        case .networkError: return "network_error"
        case .accountNotFound: return "account_not_found"
        case .weakPassword: return "weak_password"
        case .emailAlreadyInUse: return "email_already_in_use"
        case .unknown(let message): return "unknown_\(message)"
        }
    }
    
    var message: String {
        switch self {
        case .invalidCredentials: return "Invalid email or password. Please try again."
        case .networkError: return "Network error. Please check your connection and try again."
        case .accountNotFound: return "Account not found. Please check your email or sign up."
        case .weakPassword: return "Password is too weak. Please use at least 6 characters."
        case .emailAlreadyInUse: return "Email is already in use. Please try another or sign in."
        case .unknown(let message): return "An error occurred: \(message)"
        }
    }
}
