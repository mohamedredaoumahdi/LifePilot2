//
//  FirebaseConfigCheck.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 17/03/2025.
//

import Foundation
import Firebase
import FirebaseAuth

class FirebaseConfigCheck {
    
    static func verifySetup() {
        // Check if Firebase is initialized
        if FirebaseApp.app() == nil {
            print("❌ ERROR: Firebase is not properly initialized")
        } else {
            print("✅ Firebase is initialized")
        }
        
        // Check if Auth is available
        if Auth.auth() != nil {
            print("✅ Firebase Auth is available")
            
            // Check if current user exists
            if let user = Auth.auth().currentUser {
                print("👤 Currently signed in user: \(user.email ?? "no email"), UID: \(user.uid)")
            } else {
                print("⚠️ No user is currently signed in")
            }
            
            // Verify email/password provider is enabled (indirectly)
            print("ℹ️ Testing if email/password provider is enabled...")
            Auth.auth().fetchSignInMethods(forEmail: "test@example.com") { (providers, error) in
                if let error = error {
                    print("❌ Error checking sign-in methods: \(error.localizedDescription)")
                    
                    if let nsError = error as NSError? {
                        if nsError.code == 17999 {
                            print("❌ Firebase project may not have email/password authentication enabled")
                        } else {
                            print("ℹ️ Error code: \(nsError.code), domain: \(nsError.domain)")
                        }
                    }
                } else {
                    print("✅ Sign-in methods check successful")
                }
            }
        } else {
            print("❌ ERROR: Firebase Auth is not available")
        }
        
        // Check Firebase App ID and API Key
        if let options = FirebaseApp.app()?.options {
            let apiKey = options.apiKey ?? ""
            let appID = options.googleAppID ?? ""
            
            if apiKey.isEmpty || apiKey == "YOUR_API_KEY" {
                print("❌ Invalid API Key configuration: \(apiKey)")
            } else {
                print("✅ API Key is configured: \(String(apiKey.prefix(4)))...")
            }
            
            if appID.isEmpty || appID == "YOUR_APP_ID" {
                print("❌ Invalid App ID configuration: \(appID)")
            } else {
                print("✅ App ID is configured: \(String(appID.prefix(8)))...")
            }
        } else {
            print("❌ ERROR: Cannot access Firebase options")
        }
    }
}
