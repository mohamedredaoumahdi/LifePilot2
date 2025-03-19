//
//  SettingsView.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 17/03/2025.
//

import Foundation
import SwiftUI
import Firebase
import Combine
import FirebaseAuth

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showSignOutConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("Account")) {
                if let user = authViewModel.currentUser {
                    HStack {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            /*
            Section(header: Text("Preferences")) {
                Button(action: {
                    // Reset onboarding flag for testing
                    hasCompletedOnboarding = false
                }) {
                    Text("Reset Onboarding")
                        .foregroundColor(.blue)
                }
            }
            */
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppConfig.App.versionNumber)
                        .foregroundColor(.secondary)
                }
                
                // Display Firebase auth status
                HStack {
                    Button(action: {
                        showSignOutConfirmation = true
                    }) {
                        HStack {
                            Text("Sign Out")
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            if case .authenticating = authViewModel.authState {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(authViewModel.authState == .authenticating)
                    .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                        Button("Sign Out", role: .destructive) {
                            authViewModel.signOut()
                        }
                        
                        Button("Cancel", role: .cancel) {
                            // Just close the dialog
                        }
                    } message: {
                        Text("Are you sure you want to sign out?")
                    }
                }
            }
            
            // Show errors if any
            if let error = authViewModel.error {
                Section(header: Text("Errors")) {
                    Text(error.message)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
    }
    
    // Helper to show authentication status
    private var authStatusText: String {
        switch authViewModel.authState {
        case .initializing:
            return "Initializing"
        case .unauthenticated:
            return "Signed Out"
        case .authenticating:
            return "Processing"
        case .authenticated:
            return "Signed In"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var authStatusColor: Color {
        switch authViewModel.authState {
        case .authenticated:
            return .green
        case .unauthenticated:
            return .orange
        case .initializing, .authenticating:
            return .blue
        case .error:
            return .red
        }
    }
}
