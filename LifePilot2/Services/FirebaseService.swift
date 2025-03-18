import Foundation
import Combine
import Firebase
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Service Errors
enum FirebaseServiceError: Error, LocalizedError {
    case notImplemented
    case documentNotFound
    case saveError
    case deleteError
    case fetchError
    case authenticationError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Feature not implemented"
        case .documentNotFound:
            return "Document not found"
        case .saveError:
            return "Failed to save data"
        case .deleteError:
            return "Failed to delete data"
        case .fetchError:
            return "Failed to fetch data"
        case .authenticationError:
            return "Authentication error"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

// MARK: - Firebase Auth Service Protocol
protocol FirebaseAuthServiceProtocol {
    var currentUser: AnyPublisher<UserProfile?, Never> { get }
    func signIn(email: String, password: String) -> AnyPublisher<UserProfile, FirebaseServiceError>
    func signUp(email: String, password: String, name: String) -> AnyPublisher<UserProfile, FirebaseServiceError>
    func signOut() -> AnyPublisher<Void, FirebaseServiceError>
    func resetPassword(email: String) -> AnyPublisher<Void, FirebaseServiceError>
    func resetAuthState() -> AnyPublisher<Void, FirebaseServiceError>
}

// MARK: - Firebase Database Service Protocol
protocol FirebaseDatabaseServiceProtocol {
    // User Profile
    func saveUserProfile(_ profile: UserProfile) -> AnyPublisher<Void, FirebaseServiceError>
    func getUserProfile(userId: String) -> AnyPublisher<UserProfile, FirebaseServiceError>
    func updateUserProfile(_ profile: UserProfile) -> AnyPublisher<Void, FirebaseServiceError>
    
    // Analysis and Recommendations
    func saveAnalysis(_ analysis: PersonalizedAnalysis) -> AnyPublisher<Void, FirebaseServiceError>
    func getAnalysis(userId: String) -> AnyPublisher<PersonalizedAnalysis?, FirebaseServiceError>
    func observeAnalysis(userId: String) -> AnyPublisher<PersonalizedAnalysis?, FirebaseServiceError>
    
    // Weekly Schedule
    func saveSchedule(_ schedule: WeeklySchedule) -> AnyPublisher<Void, FirebaseServiceError>
    func getSchedule(userId: String) -> AnyPublisher<WeeklySchedule?, FirebaseServiceError>
    func observeSchedule(userId: String) -> AnyPublisher<WeeklySchedule?, FirebaseServiceError>
}

// MARK: - Firebase Auth Service Implementation
class FirebaseAuthService: FirebaseAuthServiceProtocol {
    private let currentUserSubject = CurrentValueSubject<UserProfile?, Never>(nil)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var userProfileListener: ListenerRegistration?
    private let db = Firestore.firestore()
        
    var currentUser: AnyPublisher<UserProfile?, Never> {
        return currentUserSubject.eraseToAnyPublisher()
    }
    
    init() {
        print("Initializing FirebaseAuthService")
        
        // Check if a user is already signed in with Firebase
        if let firebaseUser = Auth.auth().currentUser {
            print("Firebase user already signed in: \(firebaseUser.email ?? "unknown")")
            // Fetch the user profile from Firestore
            fetchUserProfile(userId: firebaseUser.uid)
        }
        
        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            if let user = user {
                print("Firebase auth state changed: User signed in")
                // User is signed in, fetch user profile
                self?.fetchUserProfile(userId: user.uid)
            } else {
                print("Firebase auth state changed: User signed out")
                // User is signed out
                self?.currentUserSubject.send(nil)
            }
        }
    }
    
    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userProfileListener?.remove()
    }
    
    func signIn(email: String, password: String) -> AnyPublisher<UserProfile, FirebaseServiceError> {
        return Future<UserProfile, FirebaseServiceError> { promise in
            // Ensure we're not calling this before Firebase is initialized
            guard Auth.auth() != nil else {
                print("Error: Firebase Auth not initialized")
                promise(.failure(.authenticationError))
                return
            }
            
            // Log the attempt
            print("Firebase signIn attempt with email: \(email)")
            
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result, error) in
                guard let self = self else { return }
                
                if let error = error {
                    let nsError = error as NSError
                    print("Sign in error code: \(nsError.code), domain: \(nsError.domain), description: \(error.localizedDescription)")
                    
                    // Map Firebase errors to our service errors
                    switch nsError.code {
                    case 17004: // Malformed credentials
                        promise(.failure(.authenticationError))
                    case 17005, 17011: // User not found
                        promise(.failure(.documentNotFound))
                    case 17009: // Wrong password
                        promise(.failure(.authenticationError))
                    case 17020: // Network error
                        promise(.failure(.fetchError))
                    default:
                        promise(.failure(.authenticationError))
                    }
                    return
                }
                
                if let firebaseUser = result?.user {
                    let userId = firebaseUser.uid
                    print("Sign in successful for userId: \(userId)")
                    
                    // Try to fetch the user profile from Firestore
                    self.fetchUserProfile(userId: userId) { result in
                        switch result {
                        case .success(let profile):
                            // Profile found, return it
                            print("User profile found, proceeding with sign in")
                            promise(.success(profile))
                            
                        case .failure(.documentNotFound):
                            // Profile not found, create a new one
                            print("User profile not found, creating a new profile")
                            
                            // Get user display name or use email as fallback
                            let name = firebaseUser.displayName ?? email.components(separatedBy: "@").first ?? "User"
                            
                            // Create new profile
                            let newProfile = UserProfile(
                                id: userId,
                                name: name,
                                email: email,
                                createdAt: Date(),
                                onboardingCompleted: false  // New users need to complete onboarding
                            )
                            
                            // Save to Firestore
                            self.saveNewUserProfile(newProfile) { saveResult in
                                switch saveResult {
                                case .success:
                                    print("New user profile created successfully")
                                    promise(.success(newProfile))
                                    self.currentUserSubject.send(newProfile)
                                    
                                case .failure(let saveError):
                                    print("Failed to create new user profile: \(saveError)")
                                    promise(.failure(saveError))
                                }
                            }
                            
                        case .failure(let error):
                            // Other error occurred
                            print("Failed to fetch user profile: \(error)")
                            promise(.failure(error))
                        }
                    }
                } else {
                    print("Sign in returned no user ID")
                    promise(.failure(.authenticationError))
                }
            }
        }.eraseToAnyPublisher()
    }

    // Helper method to save a new user profile
    private func saveNewUserProfile(_ profile: UserProfile, completion: @escaping (Result<Void, FirebaseServiceError>) -> Void) {
        db.collection(AppConfig.Firebase.userCollectionName)
            .document(profile.id)
            .setData([
                "id": profile.id,
                "name": profile.name,
                "email": profile.email,
                "createdAt": profile.createdAt,
                "personalityType": profile.personalityType as Any,
                "onboardingCompleted": profile.onboardingCompleted,
                "sleepPreference": profile.sleepPreference.rawValue,
                "activityLevel": profile.activityLevel.rawValue,
                "focusAreas": profile.focusAreas.map { $0.rawValue },
                "currentChallenges": profile.currentChallenges.map { $0.rawValue }
            ]) { error in
                if let error = error {
                    print("Error saving new user profile: \(error.localizedDescription)")
                    completion(.failure(.saveError))
                } else {
                    completion(.success(()))
                }
            }
    }
    
    func signUp(email: String, password: String, name: String) -> AnyPublisher<UserProfile, FirebaseServiceError> {
        return Future<UserProfile, FirebaseServiceError> { promise in
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result, error) in
                if let error = error {
                    let nsError = error as NSError
                    print("Sign up error: \(error.localizedDescription), code: \(nsError.code)")
                    
                    switch nsError.code {
                    case 17007: // Email already in use
                        promise(.failure(.authenticationError))
                    case 17026: // Password too weak
                        promise(.failure(.authenticationError))
                    default:
                        promise(.failure(.authenticationError))
                    }
                    return
                }
                
                if let userId = result?.user.uid {
                    // Create a new user profile
                    let newUser = UserProfile(
                        id: userId,
                        name: name,
                        email: email,
                        onboardingCompleted: false
                    )
                    
                    // Save the new user to Firestore
                    self?.db.collection(AppConfig.Firebase.userCollectionName)
                        .document(userId)
                        .setData([
                            "id": newUser.id,
                            "name": newUser.name,
                            "email": newUser.email,
                            "createdAt": newUser.createdAt,
                            "personalityType": newUser.personalityType as Any,
                            "onboardingCompleted": newUser.onboardingCompleted,
                            "sleepPreference": newUser.sleepPreference.rawValue,
                            "activityLevel": newUser.activityLevel.rawValue,
                            "focusAreas": newUser.focusAreas.map { $0.rawValue },
                            "currentChallenges": newUser.currentChallenges.map { $0.rawValue }
                        ]) { error in
                            if let error = error {
                                print("Error saving user: \(error.localizedDescription)")
                                promise(.failure(.saveError))
                                return
                            }
                            
                            promise(.success(newUser))
                            self?.currentUserSubject.send(newUser)
                        }
                } else {
                    promise(.failure(.authenticationError))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func signOut() -> AnyPublisher<Void, FirebaseServiceError> {
        return Future<Void, FirebaseServiceError> { promise in
            do {
                try Auth.auth().signOut()
                promise(.success(()))
            } catch {
                print("Sign out error: \(error.localizedDescription)")
                promise(.failure(.authenticationError))
            }
        }.eraseToAnyPublisher()
    }
    
    func resetPassword(email: String) -> AnyPublisher<Void, FirebaseServiceError> {
        return Future<Void, FirebaseServiceError> { promise in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error = error {
                    print("Password reset error: \(error.localizedDescription)")
                    promise(.failure(.authenticationError))
                    return
                }
                
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }
    
    private func fetchUserProfile(userId: String, completion: ((Result<UserProfile, FirebaseServiceError>) -> Void)? = nil) {
            print("Fetching user profile for userId: \(userId)")
            
            // Cancel any existing listener
            userProfileListener?.remove()
            
            // Listen for real-time updates to the user profile
            userProfileListener = db.collection(AppConfig.Firebase.userCollectionName)
                .document(userId)
                .addSnapshotListener { [weak self] (snapshot, error) in
                    if let error = error {
                        print("Error listening to user profile: \(error.localizedDescription)")
                        self?.currentUserSubject.send(nil)
                        completion?(.failure(.fetchError))
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        print("User document does not exist for userId: \(userId)")
                        self?.currentUserSubject.send(nil)
                        completion?(.failure(.documentNotFound))
                        return
                    }
                    
                    if let data = snapshot.data() {
                        // Convert Firestore document to UserProfile using manual conversion
                        let id = data["id"] as? String ?? userId
                        let name = data["name"] as? String ?? ""
                        let email = data["email"] as? String ?? ""
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let personalityType = data["personalityType"] as? String
                        let onboardingCompleted = data["onboardingCompleted"] as? Bool ?? false
                        
                        let sleepPreferenceString = data["sleepPreference"] as? String ?? SleepPreference.neutral.rawValue
                        let sleepPreference = SleepPreference(rawValue: sleepPreferenceString) ?? .neutral
                        
                        let activityLevelString = data["activityLevel"] as? String ?? ActivityLevel.moderate.rawValue
                        let activityLevel = ActivityLevel(rawValue: activityLevelString) ?? .moderate
                        
                        let focusAreaStrings = data["focusAreas"] as? [String] ?? []
                        let focusAreas = focusAreaStrings.compactMap { FocusArea(rawValue: $0) }
                        
                        let challengeStrings = data["currentChallenges"] as? [String] ?? []
                        let currentChallenges = challengeStrings.compactMap { Challenge(rawValue: $0) }
                        
                        let profile = UserProfile(
                            id: id,
                            name: name,
                            email: email,
                            createdAt: createdAt,
                            personalityType: personalityType,
                            onboardingCompleted: onboardingCompleted,
                            sleepPreference: sleepPreference,
                            activityLevel: activityLevel,
                            focusAreas: focusAreas,
                            currentChallenges: currentChallenges
                        )
                        
                        print("Successfully fetched user profile: \(name), onboardingCompleted: \(onboardingCompleted)")
                        self?.currentUserSubject.send(profile)
                        completion?(.success(profile))
                    } else {
                        print("User document exists but data is empty for userId: \(userId)")
                        self?.currentUserSubject.send(nil)
                        completion?(.failure(.documentNotFound))
                    }
                }
        }
    
    func resetAuthState() -> AnyPublisher<Void, FirebaseServiceError> {
           return Future<Void, FirebaseServiceError> { promise in
               do {
                   // First, clear the current user subject
                   self.currentUserSubject.send(nil)
                   
                   // Cancel any existing listener
                   self.userProfileListener?.remove()
                   self.userProfileListener = nil
                   
                   // Then sign out from Firebase
                   try Auth.auth().signOut()
                   
                   print("Auth state reset successfully")
                   promise(.success(()))
               } catch {
                   print("Reset auth state error: \(error.localizedDescription)")
                   promise(.failure(.authenticationError))
               }
           }.eraseToAnyPublisher()
       }
}

// MARK: - Firebase Database Service Implementation
class FirebaseDatabaseService: FirebaseDatabaseServiceProtocol {
    private let db = Firestore.firestore()
    private var analysisListeners: [String: ListenerRegistration] = [:]
    private var scheduleListeners: [String: ListenerRegistration] = [:]
    
    // MARK: - User Profile Operations
    
    func saveUserProfile(_ profile: UserProfile) -> AnyPublisher<Void, FirebaseServiceError> {
        return Future<Void, FirebaseServiceError> { promise in
            // Convert UserProfile to dictionary manually
            let data: [String: Any] = [
                "id": profile.id,
                "name": profile.name,
                "email": profile.email,
                "createdAt": profile.createdAt,
                "personalityType": profile.personalityType as Any,
                "onboardingCompleted": profile.onboardingCompleted,
                "sleepPreference": profile.sleepPreference.rawValue,
                "activityLevel": profile.activityLevel.rawValue,
                "focusAreas": profile.focusAreas.map { $0.rawValue },
                "currentChallenges": profile.currentChallenges.map { $0.rawValue }
            ]
            
            self.db.collection(AppConfig.Firebase.userCollectionName)
                .document(profile.id)
                .setData(data, merge: true) { error in
                    if let error = error {
                        print("Error saving profile: \(error.localizedDescription)")
                        promise(.failure(.saveError))
                        return
                    }
                    
                    promise(.success(()))
                }
        }.eraseToAnyPublisher()
    }
    
    func getUserProfile(userId: String) -> AnyPublisher<UserProfile, FirebaseServiceError> {
        return Future<UserProfile, FirebaseServiceError> { promise in
            self.db.collection(AppConfig.Firebase.userCollectionName)
                .document(userId)
                .getDocument { (snapshot, error) in
                    if let error = error {
                        print("Error fetching user: \(error.localizedDescription)")
                        promise(.failure(.fetchError))
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        print("User document does not exist")
                        promise(.failure(.documentNotFound))
                        return
                    }
                    
                    if let data = snapshot.data() {
                        // Convert Firestore document to UserProfile using manual conversion
                        let id = data["id"] as? String ?? userId
                        let name = data["name"] as? String ?? ""
                        let email = data["email"] as? String ?? ""
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let personalityType = data["personalityType"] as? String
                        let onboardingCompleted = data["onboardingCompleted"] as? Bool ?? false
                        
                        let sleepPreferenceString = data["sleepPreference"] as? String ?? SleepPreference.neutral.rawValue
                        let sleepPreference = SleepPreference(rawValue: sleepPreferenceString) ?? .neutral
                        
                        let activityLevelString = data["activityLevel"] as? String ?? ActivityLevel.moderate.rawValue
                        let activityLevel = ActivityLevel(rawValue: activityLevelString) ?? .moderate
                        
                        let focusAreaStrings = data["focusAreas"] as? [String] ?? []
                        let focusAreas = focusAreaStrings.compactMap { FocusArea(rawValue: $0) }
                        
                        let challengeStrings = data["currentChallenges"] as? [String] ?? []
                        let currentChallenges = challengeStrings.compactMap { Challenge(rawValue: $0) }
                        
                        let profile = UserProfile(
                            id: id,
                            name: name,
                            email: email,
                            createdAt: createdAt,
                            personalityType: personalityType,
                            onboardingCompleted: onboardingCompleted,
                            sleepPreference: sleepPreference,
                            activityLevel: activityLevel,
                            focusAreas: focusAreas,
                            currentChallenges: currentChallenges
                        )
                        
                        promise(.success(profile))
                    } else {
                        promise(.failure(.documentNotFound))
                    }
                }
        }.eraseToAnyPublisher()
    }
    
    func updateUserProfile(_ profile: UserProfile) -> AnyPublisher<Void, FirebaseServiceError> {
        return saveUserProfile(profile)
    }
    
    // MARK: - Analysis and Recommendations
    
    func saveAnalysis(_ analysis: PersonalizedAnalysis) -> AnyPublisher<Void, FirebaseServiceError> {
        return Future<Void, FirebaseServiceError> { promise in
            // Convert insights to array of dictionaries
            let insightsData = analysis.insights.map { insight -> [String: Any] in
                return [
                    "id": insight.id,
                    "title": insight.title,
                    "description": insight.description,
                    "focusArea": insight.focusArea.rawValue,
                    "severity": insight.severity.rawValue
                ]
            }
            
            // Convert recommendations to array of dictionaries
            let recommendationsData = analysis.recommendations.map { recommendation -> [String: Any] in
                var data: [String: Any] = [
                    "id": recommendation.id,
                    "title": recommendation.title,
                    "description": recommendation.description,
                    "focusArea": recommendation.focusArea.rawValue,
                    "impact": recommendation.impact.rawValue,
                    "timeframe": recommendation.timeframe.rawValue
                ]
                
                if let accepted = recommendation.accepted {
                    data["accepted"] = accepted
                }
                
                return data
            }
            
            // Convert evidence links to array of dictionaries if they exist
            var evidenceLinksData: [[String: Any]]? = nil
            if let evidenceLinks = analysis.evidenceLinks {
                evidenceLinksData = evidenceLinks.map { evidence -> [String: Any] in
                    return [
                        "id": evidence.id,
                        "title": evidence.title,
                        "url": evidence.url.absoluteString,
                        "type": evidence.type.rawValue
                    ]
                }
            }
            
            // Create the full analysis document
            var data: [String: Any] = [
                "id": analysis.id,
                "userId": analysis.userId,
                "generatedAt": analysis.generatedAt,
                "insights": insightsData,
                "recommendations": recommendationsData
            ]
            
            if let evidenceLinksData = evidenceLinksData {
                data["evidenceLinks"] = evidenceLinksData
            }
            
            // Save to Firestore
            self.db.collection("personalizedAnalysis")
                .document(analysis.userId)
                .setData(data, merge: true) { error in
                    if let error = error {
                        print("Error saving analysis: \(error.localizedDescription)")
                        promise(.failure(.saveError))
                        return
                    }
                    
                    promise(.success(()))
                }
        }.eraseToAnyPublisher()
    }
    
    func getAnalysis(userId: String) -> AnyPublisher<PersonalizedAnalysis?, FirebaseServiceError> {
        return Future<PersonalizedAnalysis?, FirebaseServiceError> { promise in
            self.db.collection("personalizedAnalysis")
                .document(userId)
                .getDocument { (snapshot, error) in
                    if let error = error {
                        print("Error fetching analysis: \(error.localizedDescription)")
                        promise(.failure(.fetchError))
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data(), !data.isEmpty else {
                        // No analysis exists yet
                        promise(.success(nil))
                        return
                    }
                    
                    if let analysis = self.parseAnalysisData(data, userId: userId) {
                        promise(.success(analysis))
                    } else {
                        promise(.failure(.fetchError))
                    }
                }
        }.eraseToAnyPublisher()
    }
    
    func observeAnalysis(userId: String) -> AnyPublisher<PersonalizedAnalysis?, FirebaseServiceError> {
        // Cancel any existing listener for this user
        analysisListeners[userId]?.remove()
        analysisListeners.removeValue(forKey: userId)
        
        // Create a subject to publish analysis updates
        let subject = PassthroughSubject<PersonalizedAnalysis?, FirebaseServiceError>()
        
        // Set up a listener for real-time updates
        let listener = self.db.collection("personalizedAnalysis")
            .document(userId)
            .addSnapshotListener { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error listening to analysis: \(error.localizedDescription)")
                    subject.send(completion: .failure(.fetchError))
                    return
                }
                
                guard let snapshot = snapshot else {
                    subject.send(nil)
                    return
                }
                
                if snapshot.exists, let data = snapshot.data(), !data.isEmpty {
                    if let analysis = self?.parseAnalysisData(data, userId: userId) {
                        subject.send(analysis)
                    } else {
                        subject.send(completion: .failure(.fetchError))
                    }
                } else {
                    // No analysis exists yet
                    subject.send(nil)
                }
            }
        
        // Store the listener to prevent it from being deallocated
        analysisListeners[userId] = listener
        
        return subject.eraseToAnyPublisher()
    }
    
    // Helper method to parse analysis data
    private func parseAnalysisData(_ data: [String: Any], userId: String) -> PersonalizedAnalysis? {
        // Parse the analysis data
        let id = data["id"] as? String ?? UUID().uuidString
        let documentUserId = data["userId"] as? String ?? userId
        let generatedAt = (data["generatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse insights
        var insights: [Insight] = []
        if let insightsData = data["insights"] as? [[String: Any]] {
            insights = insightsData.compactMap { insightData in
                guard let id = insightData["id"] as? String,
                      let title = insightData["title"] as? String,
                      let description = insightData["description"] as? String,
                      let focusAreaString = insightData["focusArea"] as? String,
                      let severityString = insightData["severity"] as? String else {
                    return nil
                }
                
                let focusArea = FocusArea.fromString(focusAreaString)
                let severity = InsightSeverity.fromString(severityString)
                
                return Insight(
                    id: id,
                    title: title,
                    description: description,
                    focusArea: focusArea,
                    severity: severity
                )
            }
        }
        
        // Parse recommendations
        var recommendations: [Recommendation] = []
        if let recommendationsData = data["recommendations"] as? [[String: Any]] {
            recommendations = recommendationsData.compactMap { recommendationData in
                guard let id = recommendationData["id"] as? String,
                      let title = recommendationData["title"] as? String,
                      let description = recommendationData["description"] as? String,
                      let focusAreaString = recommendationData["focusArea"] as? String,
                      let impactString = recommendationData["impact"] as? String,
                      let timeframeString = recommendationData["timeframe"] as? String else {
                    return nil
                }
                
                let focusArea = FocusArea.fromString(focusAreaString)
                let impact = RecommendationImpact.fromString(impactString)
                let timeframe = TimeFrame.fromString(timeframeString)
                let accepted = recommendationData["accepted"] as? Bool
                
                return Recommendation(
                    id: id,
                    title: title,
                    description: description,
                    focusArea: focusArea,
                    impact: impact,
                    timeframe: timeframe,
                    accepted: accepted
                )
            }
        }
        
        // Parse evidence links
        var evidenceLinks: [EvidenceLink]? = nil
        if let evidenceLinksData = data["evidenceLinks"] as? [[String: Any]] {
            evidenceLinks = evidenceLinksData.compactMap { evidenceData in
                guard let id = evidenceData["id"] as? String,
                      let title = evidenceData["title"] as? String,
                      let urlString = evidenceData["url"] as? String,
                      let typeString = evidenceData["type"] as? String else {
                    return nil
                }
                
                guard let url = URL(string: urlString) else {
                    print("Invalid URL: \(urlString)")
                    return nil
                }
                
                let type = EvidenceType.fromString(typeString)
                
                return EvidenceLink(
                    id: id,
                    title: title,
                    url: url,
                    type: type
                )
            }
        }
        
        // Create the complete analysis object
        return PersonalizedAnalysis(
            id: id,
            userId: documentUserId,
            generatedAt: generatedAt,
            insights: insights,
            recommendations: recommendations,
            evidenceLinks: evidenceLinks
        )
    }
    
    // MARK: - Weekly Schedule Methods
    
    func saveSchedule(_ schedule: WeeklySchedule) -> AnyPublisher<Void, FirebaseServiceError> {
        return Future<Void, FirebaseServiceError> { promise in
            // Convert days to dictionaries
            let daysData = schedule.days.map { day -> [String: Any] in
                // Convert activities to dictionaries
                let activitiesData = day.activities.map { activity -> [String: Any] in
                    var activityData: [String: Any] = [
                        "id": activity.id,
                        "title": activity.title,
                        "startTime": activity.startTime,
                        "endTime": activity.endTime,
                        "activityType": activity.activityType.rawValue,
                        "isCompleted": activity.isCompleted,
                        "isRecommended": activity.isRecommended,
                        "color": activity.color.rawValue
                    ]
                    
                    if let description = activity.description {
                        activityData["description"] = description
                    }
                    
                    if let relatedRecommendationId = activity.relatedRecommendationId {
                        activityData["relatedRecommendationId"] = relatedRecommendationId
                    }
                    
                    if let notes = activity.notes {
                        activityData["notes"] = notes
                    }
                    
                    return activityData
                }
                
                return [
                    "id": day.id,
                    "dayOfWeek": day.dayOfWeek.rawValue,
                    "activities": activitiesData
                ]
            }
            
            // Create the full schedule document
            let data: [String: Any] = [
                "id": schedule.id,
                "userId": schedule.userId,
                "createdAt": schedule.createdAt,
                "lastModified": schedule.lastModified,
                "days": daysData
            ]
            
            // Save to Firestore
            self.db.collection("weeklySchedules")
                .document(schedule.userId)
                .setData(data) { error in
                    if let error = error {
                        print("Error saving schedule: \(error.localizedDescription)")
                        promise(.failure(.saveError))
                        return
                    }
                    
                    promise(.success(()))
                }
        }.eraseToAnyPublisher()
    }
    
    func getSchedule(userId: String) -> AnyPublisher<WeeklySchedule?, FirebaseServiceError> {
        return Future<WeeklySchedule?, FirebaseServiceError> { promise in
            self.db.collection("weeklySchedules")
                .document(userId)
                .getDocument { (snapshot, error) in
                    if let error = error {
                        print("Error fetching schedule: \(error.localizedDescription)")
                        promise(.failure(.fetchError))
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data(), !data.isEmpty else {
                        // No schedule exists yet
                        promise(.success(nil))
                        return
                    }
                    
                    if let schedule = self.parseScheduleData(data, userId: userId) {
                        promise(.success(schedule))
                    } else {
                        promise(.failure(.fetchError))
                    }
                }
        }.eraseToAnyPublisher()
    }
    
    func observeSchedule(userId: String) -> AnyPublisher<WeeklySchedule?, FirebaseServiceError> {
        // Cancel any existing listener for this user
        scheduleListeners[userId]?.remove()
        scheduleListeners.removeValue(forKey: userId)
        
        // Create a subject to publish schedule updates
        let subject = PassthroughSubject<WeeklySchedule?, FirebaseServiceError>()
        
        // Set up a listener for real-time updates
        let listener = self.db.collection("weeklySchedules")
            .document(userId)
            .addSnapshotListener { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error listening to schedule: \(error.localizedDescription)")
                    subject.send(completion: .failure(.fetchError))
                    return
                }
                
                guard let snapshot = snapshot else {
                    subject.send(nil)
                    return
                }
                
                if snapshot.exists, let data = snapshot.data(), !data.isEmpty {
                    if let schedule = self?.parseScheduleData(data, userId: userId) {
                        subject.send(schedule)
                    } else {
                        subject.send(completion: .failure(.fetchError))
                    }
                } else {
                    // No schedule exists yet
                    subject.send(nil)
                }
            }
        
        // Store the listener to prevent it from being deallocated
        scheduleListeners[userId] = listener
        
        return subject.eraseToAnyPublisher()
    }
    
    // Helper method to parse schedule data
    private func parseScheduleData(_ data: [String: Any], userId: String) -> WeeklySchedule? {
        let id = data["id"] as? String ?? UUID().uuidString
        let documentUserId = data["userId"] as? String ?? userId
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        
        var days: [DaySchedule] = []
        
        if let daysData = data["days"] as? [[String: Any]] {
            days = daysData.compactMap { dayData in
                guard let id = dayData["id"] as? String,
                      let dayOfWeekString = dayData["dayOfWeek"] as? String,
                      let dayOfWeek = DayOfWeek(rawValue: dayOfWeekString) else {
                    return nil
                }
                
                var activities: [ScheduledActivity] = []
                
                if let activitiesData = dayData["activities"] as? [[String: Any]] {
                    activities = activitiesData.compactMap { activityData in
                        guard let id = activityData["id"] as? String,
                              let title = activityData["title"] as? String,
                              let startTime = (activityData["startTime"] as? Timestamp)?.dateValue(),
                              let endTime = (activityData["endTime"] as? Timestamp)?.dateValue(),
                              let activityTypeString = activityData["activityType"] as? String,
                              let activityType = ActivityType(rawValue: activityTypeString),
                              let colorString = activityData["color"] as? String,
                              let color = ActivityColor(rawValue: colorString) else {
                            return nil
                        }
                        
                        let description = activityData["description"] as? String
                        let isCompleted = activityData["isCompleted"] as? Bool ?? false
                        let isRecommended = activityData["isRecommended"] as? Bool ?? false
                        let relatedRecommendationId = activityData["relatedRecommendationId"] as? String
                        let notes = activityData["notes"] as? String
                        
                        return ScheduledActivity(
                            id: id,
                            title: title,
                            description: description,
                            startTime: startTime,
                            endTime: endTime,
                            activityType: activityType,
                            isCompleted: isCompleted,
                            isRecommended: isRecommended,
                            relatedRecommendationId: relatedRecommendationId,
                            color: color,
                            notes: notes
                        )
                    }
                }
                
                return DaySchedule(
                    id: id,
                    dayOfWeek: dayOfWeek,
                    activities: activities
                )
            }
        }
        
        // If days is empty, initialize with default days
        if days.isEmpty {
            for dayOfWeek in DayOfWeek.allCases {
                days.append(DaySchedule(dayOfWeek: dayOfWeek))
            }
        }
        
        return WeeklySchedule(
            id: id,
            userId: documentUserId,
            createdAt: createdAt,
            lastModified: lastModified,
            days: days
        )
    }
    
    // Clean up listeners when deinitialized
    deinit {
        // Remove all active listeners
        for (_, listener) in analysisListeners {
            listener.remove()
        }
        
        for (_, listener) in scheduleListeners {
            listener.remove()
        }
    }
}
