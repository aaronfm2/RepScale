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
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.16, green: 0.16, blue: 0.18) : Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 1. Profile Header
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
                                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 3)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("RepScale Premium")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Unlock advanced stats & icons")
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(LinearGradient(colors: [.yellow.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
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
                    
                    Text("RepScale v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 10)
                }
                .padding()
            }
            .background(appBackgroundColor)
            .navigationTitle("Profile")
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

// MARK: - NEW Premium View (Sticky Footer Version)

struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    var appBackgroundColor: Color
    
    // State for selected plan
    enum SubscriptionPeriod { case yearly, monthly }
    @State private var selectedPeriod: SubscriptionPeriod = .yearly
    
    var body: some View {
        ZStack {
            // Background
            appBackgroundColor.ignoresSafeArea()
            
            // 1. Scrollable Content (Header + Features)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        // Hero Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Unlock Full Potential")
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                
                                Text("Advanced analytics, unlimited history, and custom tools to reach your goals faster.")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Comparison Table Card
                        VStack(spacing: 0) {
                            // Table Header
                            HStack {
                                Text("Features")
                                    .font(.footnote.bold())
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Free")
                                    .font(.footnote.bold())
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50)
                                
                                Text("Pro")
                                    .font(.footnote.bold())
                                    .textCase(.uppercase)
                                    .foregroundStyle(.blue)
                                    .frame(width: 50)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            
                            Divider()
                            
                            VStack(spacing: 0) {
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
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05)))
                        .padding(.horizontal)
                        
                        // spacer large enough so content clears the fixed footer
                        Color.clear.frame(height: 250)
                    }
                }
            }
            
            // 2. Fixed Bottom Sheet (Plans + CTA)
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    
                    // Plan Selection (Visible Always)
                    HStack(spacing: 10) {
                        // Monthly
                        PlanSelectionCard(
                            title: "Monthly",
                            price: "£1.99",
                            subtitle: "/mo",
                            isSelected: selectedPeriod == .monthly,
                            badge: nil // No badge
                        )
                        .onTapGesture { withAnimation { selectedPeriod = .monthly } }
                        
                        // Yearly
                        PlanSelectionCard(
                            title: "Yearly",
                            price: "£14.99",
                            subtitle: "/yr",
                            isSelected: selectedPeriod == .yearly,
                            badge: "BEST VALUE"
                        )
                        .onTapGesture { withAnimation { selectedPeriod = .yearly } }
                    }
                    
                    // Main CTA
                    Button(action: {
                        // Purchase Logic
                    }) {
                        Text(ctaText)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Links
                    HStack(spacing: 16) {
                        Button("Restore Purchases") { /* Logic */ }
                        Text("•")
                        Text("Auto-renewable")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(16)
                .background(.regularMaterial) // Glass effect
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var ctaText: String {
        switch selectedPeriod {
        case .yearly: return "Start 7-Day Free Trial"
        case .monthly: return "Subscribe for $1.99"
        }
    }
}

// MARK: - Premium Helper Views

struct PlanSelectionCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    let badge: String?
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price).font(.title3.bold())
                    Text(subtitle).font(.caption2).foregroundColor(.secondary)
                }
                
                // Badge Logic: Always render the Text to maintain height, but use Opacity/Colors to hide
                Text(badge ?? "BEST VALUE")
                    .font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badge != nil ? Color.green.opacity(0.15) : Color.clear)
                    .foregroundColor(badge != nil ? .green : .clear)
                    .clipShape(Capsule())
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 4, x: 0, y: 2)
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
        }
    }
}

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
                
                Image(systemName: free ? "checkmark" : "minus")
                    .foregroundColor(free ? .primary : .secondary.opacity(0.3))
                    .font(.caption.bold())
                    .frame(width: 50)
                
                Image(systemName: premium ? "checkmark" : "lock.fill")
                    .foregroundColor(premium ? .blue : .secondary)
                    .font(.caption.bold())
                    .frame(width: 50)
            }
            .padding(.horizontal)
            
            Divider().padding(.leading)
        }
    }
}
