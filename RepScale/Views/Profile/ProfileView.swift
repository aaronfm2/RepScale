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
    
    // MARK: - Dark Mode Correction
    // Matches the custom background color used in DashboardView
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - User Details
                Section {
                    HStack(spacing: 15) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30)
                                    .foregroundColor(.accentColor)
                            )
                        
                        VStack(alignment: .leading) {
                            Text("Member since \(profile.createdAt.formatted(.dateTime.year()))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    LabeledContent("Age", value: "\(profile.age)")
                    LabeledContent("Gender", value: profile.gender)
                    LabeledContent("Height", value: heightString)
                } header: {
                    Text("Personal Details")
                }
                
                // MARK: - Premium Section
                Section {
                    NavigationLink {
                        PremiumView(appBackgroundColor: appBackgroundColor)
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading) {
                                Text("RepScale Premium")
                                    .fontWeight(.medium)
                                Text("Unlock advanced stats & icons")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Membership")
                }
                
                // MARK: - Support
                Section {
                    NavigationLink(destination: HelpSupportView()) {
                        Label("Help Centre", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Support")
                }
                
                // MARK: - Legal / Privacy
                Section {
                    Link(destination: URL(string: "https://www.repscale.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text("Legal")
                }
            }
            // Fix: Override default List background to match Dashboard
            .scrollContentBackground(.hidden)
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

// MARK: - Premium View
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
