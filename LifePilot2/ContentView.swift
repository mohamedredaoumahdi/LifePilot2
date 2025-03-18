import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to LifePilot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Your personal life transformation coach")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                NavigationLink(destination: OnboardingView()) {
                    Text("Start Onboarding")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
        }
    }
}
