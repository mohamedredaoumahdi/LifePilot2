//
//  AuthView.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 17/03/2025.
//

import Foundation
import SwiftUI
import Firebase
import Combine
import FirebaseAuth

// MARK: - Authentication View
struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @FocusState private var focusedField: FocusField?
    
    
    
    enum FocusField {
            case name, email, password
        }
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack {
                        // App logo
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("LifePilot")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your personal life transformation coach")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 40)
                        
                        // Form fields
                        VStack(spacing: 20) {
                            if isSignUp {
                                TextField("Name", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .email
                                    }
                            }
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit {
                                    attemptAuthentication()
                                }
                        }
                        .padding(.horizontal)
                        
                        // Error message with better formatting
                        // In the AuthView body
                        // Replace the error message section with this
                        if let error = authViewModel.error {
                            AuthErrorView(error: error) {
                                // Dismiss the error
                                authViewModel.error = nil
                            }
                        }
                        
                        // Action button
                        // Updated part of the AuthView body
                        Button(action: attemptAuthentication) {
                            if case .authenticating = authViewModel.authState {
                                AuthLoadingView(message: isSignUp ? "Creating your account..." : "Signing you in...")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(authViewModel.authState == .authenticating || !isValidForm)
                        .padding(.horizontal)
                        .padding(.top)
                        .animation(.spring(), value: authViewModel.authState)
                        
                        // Toggle between sign in and sign up
                        Button(action: {
                            isSignUp.toggle()
                            // Clear error when switching modes
                            authViewModel.error = nil
                            // Clear fields when switching modes
                            if isSignUp {
                                // When switching to sign up, keep the email if entered
                                name = ""
                                password = ""
                            } else {
                                // When switching to sign in, keep the email if entered
                                name = ""
                                password = ""
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.blue)
                                .padding()
                        }
                        
                        // Reset authentication button for troubleshooting
                        Button(action: {
                            authViewModel.resetAuthState()
                        }) {
                            Text("Reset Authentication")
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationBarHidden(true)
                // Dismiss keyboard when tapping outside
                .onTapGesture {
                    focusedField = nil
                }
                // Show/hide keyboard based on focus
                .animation(.default, value: focusedField)
            }
        }
        
        private func attemptAuthentication() {
            // Hide keyboard first
            focusedField = nil
            
            if isSignUp {
                authViewModel.signUp(email: email, password: password, name: name)
            } else {
                authViewModel.signIn(email: email, password: password)
            }
        }
        
        private var isValidForm: Bool {
            if isSignUp {
                return !email.isEmpty && !password.isEmpty && !name.isEmpty && password.count >= 6
            } else {
                return !email.isEmpty && !password.isEmpty
            }
        }
}
