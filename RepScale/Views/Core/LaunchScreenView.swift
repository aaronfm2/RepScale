import SwiftUI
import SwiftData

struct LaunchScreenView: View {
    @Query var userProfiles: [UserProfile]
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    
    // Controls the "Loading..." overlay
    @State private var showLaunchScreen: Bool = true
    
    var body: some View {
        ZStack {
            // 1. THE UNDERLYING APP CONTENT
            Group {
                // If we found a profile (synced from Cloud), go to Main App
                if let profile = userProfiles.first {
                    MainTabView(profile: profile)
                        .preferredColorScheme(profile.isDarkMode ? .dark : .light)
                        .onAppear {
                            // Sync local flag if we found a cloud profile
                            if !isOnboardingCompleted { isOnboardingCompleted = true }
                        }
                }
                // Otherwise, show Onboarding
                else {
                    OnboardingView()
                }
            }
            .zIndex(0)
            
            // 2. THE LAUNCH SCREEN OVERLAY
            // We use opacity + allowsHitTesting instead of 'if' to prevent click-blocking bugs
            LaunchScreen()
                .opacity(showLaunchScreen ? 1 : 0)
                .allowsHitTesting(showLaunchScreen) // CRITICAL FIX: Ensures clicks pass through when hidden
                .animation(.easeInOut(duration: 0.4), value: showLaunchScreen)
                .zIndex(1)
                .onAppear {
                    handleAppLaunch()
                }
        }
    }
    
    // MARK: - Launch Logic
    private func handleAppLaunch() {
        // SCENARIO A: Known User (Flag is set)
        // We expect data to be there. If it is, dismiss immediately.
        if isOnboardingCompleted && !userProfiles.isEmpty {
            showLaunchScreen = false
            return
        }
        
        // SCENARIO B: Re-install / Cloud Sync
        // Flag is false, but maybe CloudKit has data?
        // Give it 2.5 seconds to find the profile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // After 2.5 seconds, fade out the overlay.
            withAnimation {
                showLaunchScreen = false
            }
        }
    }
}

// MARK: - Launch Screen Component
struct LaunchScreen: View {
    @State private var isAnimating = false
    
    // Hex #2e3337 converted to RGB 0-1 range
    private let backgroundColor = Color(red: 0.18, green: 0.20, blue: 0.215)
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // LOGO with Breathing Animation
                Image("RepScaleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                    .scaleEffect(isAnimating ? 1.05 : 1.0) // Breathing effect
                    .opacity(isAnimating ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Spacer()
                
                // Subtle Text at bottom
                Text("Syncing with iCloud...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isAnimating = true
        }
    }
}
