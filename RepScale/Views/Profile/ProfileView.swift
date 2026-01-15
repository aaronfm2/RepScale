import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    
    // --- DATA FETCHING FOR SETTINGS LOGIC ---
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    // Helper VM to calculate maintenance for the settings menu
    @State private var viewModel = DashboardViewModel()
    @State private var showingSettings = false
    
    // Helper to format height based on user preference
    private var heightString: String {
        if profile.heightUnitPreference == UnitSystem.imperial.rawValue {
            let totalInches = profile.height / 2.54
            let ft = Int(totalInches / 12)
            let inch = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(ft)' \(inch)\""
        } else {
            return String(format: "%.0f cm", profile.height)
        }
    }
    
    // MARK: - Colors
    // Matches the custom background color used in DashboardView
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    // Slightly lighter/different color for cards to pop against the background
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.16, green: 0.16, blue: 0.18) : Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 1. Profile Header
                    // Consolidates user details into a single clean card
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 35)
                                        .foregroundColor(.accentColor)
                                )
                            
                            VStack(spacing: 4) {
                                Text("Member since \(profile.createdAt.formatted(.dateTime.year()))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Horizontal Stat Grid
                        HStack(spacing: 0) {
                            ProfileStatItem(label: "Age", value: "\(profile.age)")
                            Divider().frame(height: 30)
                            ProfileStatItem(label: "Gender", value: profile.gender)
                            Divider().frame(height: 30)
                            ProfileStatItem(label: "Height", value: heightString)
                        }
                        .padding(.bottom, 4)
                    }
                    .padding()
                    .background(cardBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // MARK: - 2. Premium Banner
                    NavigationLink {
                        PremiumView(appBackgroundColor: appBackgroundColor)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.yellow)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("RepScale Premium")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("See whats available with premium")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(16)
                        .background(cardBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // MARK: - 3. Menu Options
                    VStack(spacing: 0) {
                        NavigationLink(destination: HelpSupportView()) {
                            MenuOptionRow(
                                icon: "questionmark.circle.fill",
                                color: .blue,
                                title: "Help Centre",
                                showDivider: true
                            )
                        }
                        
                        Link(destination: URL(string: "https://www.repscale.app/privacy")!) {
                            MenuOptionRow(
                                icon: "hand.raised.fill",
                                color: .gray,
                                title: "Privacy Policy",
                                showDivider: false
                            )
                        }
                    }
                    .background(cardBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Footer Version
                    Text("RepScale v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 10)
                }
                .padding()
            }
            .background(appBackgroundColor)
            .navigationTitle("Profile")
            // MARK: - Settings Toolbar
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    profile: profile,
                    estimatedMaintenance: viewModel.estimatedMaintenance,
                    currentWeight: weights.first?.weight
                )
            }
            .onAppear {
                refreshData()
            }
            .onChange(of: logs) { _, _ in refreshData() }
            .onChange(of: weights) { _, _ in refreshData() }
            .onChange(of: profile.dailyCalorieGoal) { _, _ in refreshData() }
        }
    }
    
    private func refreshData() {
        let settings = DashboardSettings(
            dailyGoal: profile.dailyCalorieGoal,
            targetWeight: profile.targetWeight,
            goalType: profile.goalType,
            maintenanceCalories: profile.maintenanceCalories,
            estimationMethod: profile.estimationMethod,
            enableCaloriesBurned: profile.enableCaloriesBurned,
            isCalorieCountingEnabled: profile.isCalorieCountingEnabled
        )
        
        viewModel.updateMetrics(
            logs: logs,
            weights: weights,
            settings: settings,
            workouts: workouts,
            weeklyGoal: profile.weeklyWorkoutGoal
        )
    }
}

// MARK: - UI Helper Components

struct ProfileStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MenuOptionRow: View {
    let icon: String
    let color: Color
    let title: String
    let showDivider: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            
            if showDivider {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Premium View (Existing)
struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    
    // Pass the background color down so this view matches too
    var appBackgroundColor: Color = Color(uiColor: .systemGroupedBackground)
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                            .padding()
                            .background(Circle().fill(.yellow.opacity(0.15)))
                        
                        VStack(spacing: 8) {
                            Text("Upgrade to Premium")
                                .font(.title.bold())
                            
                            Text("Take your fitness to the next level with advanced analytics.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Comparison Table
                    VStack(spacing: 0) {
                        // Table Header
                        HStack {
                            Text("Feature")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Free")
                                .font(.subheadline.bold())
                                .frame(width: 60)
                                .foregroundColor(.secondary)
                            
                            Text("Pro")
                                .font(.subheadline.bold())
                                .frame(width: 60)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        
                        Divider()
                        
                        // Features
                        Group {
                            FeatureRow(name: "Add & Track Workouts", free: true, premium: true)
                            FeatureRow(name: "Track Weight & Nutrition", free: true, premium: true)
                            FeatureRow(name: "Premium Dashboard Views", free: false, premium: true)
                            FeatureRow(name: "Custom Workout Templates", free: false, premium: true)
                            FeatureRow(name: "Add Progress Photos", free: false, premium: true)
                            FeatureRow(name: "View Unlimited Log History", free: false, premium: true)
                            FeatureRow(name: "Detailed Apple HealthKit Nutrition", free: false, premium: true)
                            FeatureRow(name: "Custom Muscle Groups", free: false, premium: true)
                            FeatureRow(name: "Export Data to CSV", free: false, premium: true)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Spacer
                    Color.clear.frame(height: 20)
                }
            }
            .background(appBackgroundColor) // Match background here
            
            // Fixed Footer for Pricing
            VStack(spacing: 12) {
                Divider()
                
                // Yearly Option (Primary Call to Action)
                Button(action: {
                    // In-App Purchase logic for YEARLY
                }) {
                    VStack(spacing: 4) {
                        Text("Start 7-Day Free Trial")
                            .font(.headline)
                            .fontWeight(.bold) // Highlighted
                        
                        Text("Then $14.99 / year")
                            .font(.caption)
                            .opacity(0.9)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Monthly Option (Secondary)
                Button(action: {
                    // In-App Purchase logic for MONTHLY
                }) {
                    Text("Or Monthly - $1.99 / month")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 4)
                
                Text("Auto-renewable subscription. Cancel anytime.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .background(.regularMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
        // Ensure the main container also has the background if needed
        .background(appBackgroundColor)
    }
}

// Helper for the Table Rows
struct FeatureRow: View {
    let name: String
    let free: Bool
    let premium: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                
                // Free Column
                Image(systemName: free ? "checkmark" : "minus")
                    .foregroundColor(free ? .primary : .secondary.opacity(0.5))
                    .font(.caption.bold())
                    .frame(width: 60)
                
                // Premium Column
                Image(systemName: premium ? "checkmark" : "lock.fill")
                    .foregroundColor(premium ? .blue : .secondary)
                    .font(.caption.bold())
                    .frame(width: 60)
            }
            .padding(.horizontal)
            
            Divider()
        }
    }
}
