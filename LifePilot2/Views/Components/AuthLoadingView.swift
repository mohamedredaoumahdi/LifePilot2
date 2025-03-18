//
//  AuthLoadingView.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 17/03/2025.
//

import Foundation
import SwiftUI

// Enhanced loading view for authentication
struct AuthLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("This might take a moment...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            // Start the animation when view appears
            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                // Animation will be triggered by the value change in the view definition
            }
        }
    }
}
