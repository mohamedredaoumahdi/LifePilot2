//
//  UserProfile.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 15/03/2025.
//

import Foundation


// MARK: - User Profile Model
struct UserProfile: Codable {
    var id: String
    var name: String
    var email: String
    var createdAt: Date
    var personalityType: String?
    var onboardingCompleted: Bool
    
    // User preferences and characteristics from onboarding
    var sleepPreference: SleepPreference
    var activityLevel: ActivityLevel
    var focusAreas: [FocusArea]
    var currentChallenges: [Challenge]
    
    init(id: String = UUID().uuidString,
         name: String,
         email: String,
         createdAt: Date = Date(),
         personalityType: String? = nil,
         onboardingCompleted: Bool = false,
         sleepPreference: SleepPreference = .neutral,
         activityLevel: ActivityLevel = .moderate,
         focusAreas: [FocusArea] = [],
         currentChallenges: [Challenge] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.personalityType = personalityType
        self.onboardingCompleted = onboardingCompleted
        self.sleepPreference = sleepPreference
        self.activityLevel = activityLevel
        self.focusAreas = focusAreas
        self.currentChallenges = currentChallenges
    }
}

