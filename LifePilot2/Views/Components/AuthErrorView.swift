//
//  AuthErrorView.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 17/03/2025.
//

import Foundation
import SwiftUI

// Enhanced error view
// Enhanced error view for authentication
struct AuthErrorView: View {
    let error: AuthError
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: errorIcon)
                    .foregroundColor(.red)
                
                Text(errorTitle)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let recovery = recoveryMessage {
                Text(recovery)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var errorIcon: String {
        switch error {
        case .networkError:
            return "wifi.slash"
        case .invalidCredentials, .accountNotFound:
            return "lock.slash"
        case .weakPassword, .emailAlreadyInUse:
            return "exclamationmark.triangle"
        case .unknown:
            return "exclamationmark.circle"
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .networkError:
            return "Connection Issue"
        case .invalidCredentials:
            return "Authentication Failed"
        case .accountNotFound:
            return "Account Not Found"
        case .weakPassword:
            return "Password Too Weak"
        case .emailAlreadyInUse:
            return "Email Already Used"
        case .unknown:
            return "Error"
        }
    }
    
    private var recoveryMessage: String? {
        switch error {
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidCredentials:
            return "Please verify your email and password and try again."
        case .accountNotFound:
            return "This email is not registered. Consider signing up for a new account."
        case .weakPassword:
            return "Please use a stronger password with at least 6 characters, including numbers and special characters."
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in instead."
        case .unknown:
            return nil
        }
    }
}
