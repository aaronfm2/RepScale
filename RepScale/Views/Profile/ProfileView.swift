import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    
    // --- DATA FETCHING FOR SETTINGS LOGIC ---
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    // Helper VM to calculate maintenance for the settings menu
    @State private var viewModel = DashboardViewModel()
    @State private var showingSettings = false
    
    // Export State
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    // Helper to format height based on user preference
    private var heightString: String {
        if profile.heightUnitPreference == UnitSystem.imperial.rawValue {
            let totalInches = profile.height / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            let feetString = "\(feet)'"
            let inchesString = "\(inches)\""
            return "\(feetString) \(inchesString)"
        } else {
            let centimeters = profile.height
            return String(format: "%.0f cm", centimeters)
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
                    profileHeaderCard
                    premiumBannerLink
                    menuOptionsCard
                    versionText
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
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL { ShareSheet(activityItems: [url]) }
            }
            .onAppear {
                refreshData()
            }
            .onChange(of: logs) { _, _ in refreshData() }
            .onChange(of: weights) { _, _ in refreshData() }
            .onChange(of: profile.dailyCalorieGoal) { _, _ in refreshData() }
        }
    }
    
    // MARK: - Body Subviews
    
    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            profileAvatarSection
            Divider()
            profileStatsGrid
        }
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var profileAvatarSection: some View {
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
    }
    
    private var profileStatsGrid: some View {
        HStack(spacing: 0) {
            ProfileStatItem(label: "Age", value: "\(profile.age)")
            Divider().frame(height: 30)
            ProfileStatItem(label: "Gender", value: profile.gender)
            Divider().frame(height: 30)
            ProfileStatItem(label: "Height", value: heightString)
        }
        .padding(.bottom, 4)
    }
    
    private var premiumBannerLink: some View {
        NavigationLink {
            PremiumView(appBackgroundColor: appBackgroundColor)
        } label: {
            premiumBannerContent
        }
    }
    
    private var premiumBannerContent: some View {
        HStack(spacing: 16) {
            premiumIcon
            premiumText
            Spacer()
            chevronIcon
        }
        .padding(16)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(
                    colors: [.yellow.opacity(0.5), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
    
    private var premiumIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
                .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 3)
            
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
    }
    
    private var premiumText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("RepScale Premium")
                .font(.headline)
                .foregroundColor(.primary)
            Text("See what is included with premium")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundColor(.secondary.opacity(0.5))
    }
    
    private var menuOptionsCard: some View {
        VStack(spacing: 0) {
            helpCentreLink
            exportDataButton
            instagramLink
            privacyPolicyLink
        }
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var helpCentreLink: some View {
        NavigationLink(destination: HelpSupportView(profile: profile)) {
            MenuOptionRow(
                icon: "questionmark.circle.fill",
                color: .primary,
                title: "Help Centre",
                showDivider: true
            )
        }
    }
    
    private var exportDataButton: some View {
        Button(action: exportData) {
            MenuOptionRow(
                icon: "square.and.arrow.up.fill",
                color: .primary,
                title: isExporting ? "Generating CSV..." : "Export Data to CSV",
                showDivider: true
            )
        }
        .disabled(isExporting)
    }
    
    private var instagramLink: some View {
        Group {
            if let url = URL(string: "https://www.instagram.com/repscale.app/") {
                Link(destination: url) {
                    MenuOptionRow(
                        icon: "camera.fill",
                        color: .primary,
                        title: "Follow @RepScale.app",
                        showDivider: true
                    )
                }
            }
        }
    }
    
    private var privacyPolicyLink: some View {
        Link(destination: URL(string: "https://docs.google.com/document/d/1KFxISsNEuYNN1zi5uFd3yi592zO8T4tpLCU373MZHFU/edit?usp=sharing")!) {
            MenuOptionRow(
                icon: "hand.raised.fill",
                color: .primary,
                title: "Privacy Policy",
                showDivider: false
            )
        }
    }
    
    private var versionText: some View {
        Text("RepScale v1.0.0")
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.5))
            .padding(.top, 10)
    }
    
    // MARK: - Data Methods
    
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
    
    // MARK: - Export Logic
    
    private func exportData() {
        isExporting = true
        Task {
            if let url = await generateCSV() {
                await MainActor.run {
                    self.exportURL = url
                    self.isExporting = false
                    self.showingShareSheet = true
                }
            } else { await MainActor.run { self.isExporting = false } }
        }
    }
    
    @MainActor
    private func generateCSV() -> URL? {
        let logDescriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date)])
        let weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)])
        let workoutDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])
        let goalDescriptor = FetchDescriptor<GoalPeriod>(sortBy: [SortDescriptor(\.startDate)])
        
        guard let logs = try? modelContext.fetch(logDescriptor),
              let weights = try? modelContext.fetch(weightDescriptor),
              let workouts = try? modelContext.fetch(workoutDescriptor),
              let goals = try? modelContext.fetch(goalDescriptor) else { return nil }
        
        let rawDates = logs.map { $0.date } + weights.map { $0.date } + workouts.map { $0.date }
        let uniqueDates = Set(rawDates.map { Calendar.current.startOfDay(for: $0) })
        let sortedDates = uniqueDates.sorted()
        
        let weightDays = Set(weights.map { Calendar.current.startOfDay(for: $0.date) })
        
        func getStreak(endingOn date: Date) -> Int {
            guard weightDays.contains(date) else { return 0 }
            var streak = 0
            var d = date
            while weightDays.contains(d) {
                streak += 1
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: d) else { break }
                d = prev
            }
            return streak
        }
        
        var csv = "Date,Goal Type,Current Weight,Current Weight Streak,Goal Weight,Daily weight log notes,Workout Category,Muscles Trained,Sets and Reps completed,Calories Consumed,Calories Burned,Protein,Carbs,Fats,Daily summary notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for date in sortedDates {
            let dateStr = dateFormatter.string(from: date)
            let dayLog = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            let dayWeight = weights.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            let dayWorkouts = workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            
            let activeGoal = goals.first(where: {
                let goalStart = Calendar.current.startOfDay(for: $0.startDate)
                let goalEnd = $0.endDate.map { Calendar.current.startOfDay(for: $0) }
                return goalStart <= date && (goalEnd == nil || goalEnd! >= date)
            })
            
            let rowGoalType = dayLog?.goalType ?? activeGoal?.goalType ?? ""
            let rowGoalWeight = activeGoal != nil ? String(format: "%.1f", activeGoal!.targetWeight) : ""
            let rowWeight = dayWeight != nil ? String(format: "%.1f", dayWeight!.weight) : ""
            let rowStreak = getStreak(endingOn: date)
            let rowStreakStr = rowStreak > 0 ? "\(rowStreak)" : ""
            let rowWeightNote = clean(dayWeight?.note)
            
            let categories = Set(dayWorkouts.map { $0.category }).joined(separator: "; ")
            let muscles = Set(dayWorkouts.flatMap { $0.muscleGroups }).joined(separator: "; ")
            
            var exerciseDetails: [String] = []
            for w in dayWorkouts {
                for ex in (w.exercises ?? []) {
                    var details = ex.name
                    if ex.isCardio {
                        var parts: [String] = []
                        if let dist = ex.distance, dist > 0 { parts.append("\(dist)km") }
                        if let dur = ex.duration, dur > 0 { parts.append("\(Int(dur))min") }
                        if !parts.isEmpty { details += " (" + parts.joined(separator: ", ") + ")" }
                    } else {
                        if let r = ex.reps, let wt = ex.weight { details += " \(r)x\(wt)kg" }
                    }
                    exerciseDetails.append(details)
                }
            }
            let rowSets = clean(exerciseDetails.joined(separator: "; "))
            
            let rowCalConsumed = dayLog != nil ? "\(dayLog!.caloriesConsumed)" : ""
            let rowCalBurned = dayLog != nil ? "\(dayLog!.caloriesBurned)" : ""
            let rowProt = dayLog?.protein != nil ? "\(dayLog!.protein!)" : ""
            let rowCarb = dayLog?.carbs != nil ? "\(dayLog!.carbs!)" : ""
            let rowFat = dayLog?.fat != nil ? "\(dayLog!.fat!)" : ""
            let rowLogNote = clean(dayLog?.note)
            
            let row = "\(dateStr),\(clean(rowGoalType)),\(rowWeight),\(rowStreakStr),\(rowGoalWeight),\(rowWeightNote),\(clean(categories)),\(clean(muscles)),\(rowSets),\(rowCalConsumed),\(rowCalBurned),\(rowProt),\(rowCarb),\(rowFat),\(rowLogNote)\n"
            csv.append(row)
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "RepScale_Export_\(dateFormatter.string(from: Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    private func clean(_ input: String?) -> String {
        guard let input = input, !input.isEmpty else { return "" }
        var cleaned = input.replacingOccurrences(of: "\"", with: "\"\"")
        if cleaned.contains(",") || cleaned.contains("\n") {
            cleaned = "\"\(cleaned)\""
        }
        return cleaned
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

// MARK: - ShareSheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
        case .monthly: return "Subscribe for £1.99"
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
