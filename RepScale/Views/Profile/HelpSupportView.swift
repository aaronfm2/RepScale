import SwiftUI

struct HelpSupportView: View {
    var profile: UserProfile
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var formulaBoxColor: Color {
        cardBackgroundColor
    }
    
    var body: some View {
        Form {
            // MARK: - Section: Apple HealthKit
            Section(header: Text("Apple HealthKit")) {
                
                // 1. Nutrition Sync (Existing)
                NavigationLink(destination: AnswerView(profile: profile, title: "Nutrition Sync") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How it works")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("RepScale automatically imports nutrition data from apps like **MyFitnessPal**, **Cronometer**, or **Lose It!** via Apple Health.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Setup Guide")
                                .font(.title2).bold().foregroundColor(.blue)
                            
                            StepCard(num: 1, title: "Configure Nutrition App", desc: "In your food logger settings, enable **Write** to Apple Health.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Configure RepScale", desc: "In iOS Settings > Health > Data Access, allow RepScale to **Read** Dietary Energy.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Text("Sync Nutrition (MyFitnessPal)")
                        .foregroundColor(.primary)
                }
                
                // 2. Weight Sync (New)
                NavigationLink(destination: AnswerView(profile: profile, title: "Weight Sync") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Smart Scales")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("If you use a smart scale (e.g., Withings, Garmin, Renpho), RepScale can automatically read your weigh-ins from Apple Health.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Setup Guide")
                                .font(.title2).bold().foregroundColor(.blue)
                            
                            StepCard(num: 1, title: "Connect Scale", desc: "Ensure your scale's official app is syncing weight data to Apple Health.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Allow Access", desc: "Open RepScale > Settings > Tracking > Enable HealthKit Sync.", bg: formulaBoxColor)
                        }
                        Text("Manual entries in RepScale will also sync back to Apple Health.")
                            .font(.callout).italic().foregroundColor(.secondary)
                    }
                }) {
                    Text("Sync Smart Scales & Weight")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            // MARK: - Section: Weight & Goals
            Section(header: Text("Weight & Goals")) {
                
                // 1. How to Log Weight
                NavigationLink(destination: AnswerView(profile: profile, title: "Logging Weight") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Logging Options")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("Consistency is key. Try to weigh yourself at the same time every day (best in the morning after using the bathroom).")
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Log")
                                .font(.title2).bold().foregroundColor(.blue)
                            StepCard(num: 1, title: "Weight Tab", desc: "Navigate to the Weight tab using the scale icon at the bottom.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Quick Add", desc: "Tap the Blue + button in the bottom right corner.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Text("How to log weight")
                        .foregroundColor(.primary)
                }
                
                // 2. Configure Goal
                NavigationLink(destination: AnswerView(profile: profile, title: "Configuring Goals") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goal Types")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("You can change your strategy at any time in Settings.")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
                                    Text("**Cutting:** Calorie deficit to lose fat.")
                                }
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill").foregroundColor(.red)
                                    Text("**Bulking:** Calorie surplus to build muscle.")
                                }
                                HStack {
                                    Image(systemName: "equal.circle.fill").foregroundColor(.blue)
                                    Text("**Maintenance:** Eat at equilibrium.")
                                }
                            }
                            .padding()
                            .background(formulaBoxColor)
                            .cornerRadius(12)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Change")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("Go to **Settings > Strategy > Reconfigure Goal** to run the setup wizard again.")
                        }
                    }
                }) {
                    Text("How to configure a goal")
                        .foregroundColor(.primary)
                }
                
                // 3. Maintenance Estimation (Moved from Common)
                NavigationLink(destination: AnswerView(profile: profile, title: "Maintenance Estimation") {
                    VStack(alignment: .leading, spacing: 24) {
                        // --- Formula Estimate Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Formula Estimate").font(.title2).bold().foregroundColor(.blue)
                            Text("Based on the **Mifflin-St Jeor** equation multiplied by your activity level.")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BMR = (10 × weight) + (6.25 × height) - (5 × age) + s")
                                    .font(.system(.callout, design: .monospaced)).fontWeight(.medium)
                            }
                            .padding().frame(maxWidth: .infinity, alignment: .leading).background(formulaBoxColor).cornerRadius(12)
                        }
                        Divider()
                        // --- App Estimate Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("App Estimate").font(.title2).bold().foregroundColor(.blue)
                            Text("Your **True Maintenance** is calculated by analyzing your actual data over the last 30 days.")
                            Text("Maintenance = Avg. Intake - Daily Surplus").font(.system(.callout, design: .monospaced))
                        }
                    }
                }) {
                    Text("How is maintenance estimated?")
                        .foregroundColor(.primary)
                }
                
                // 4. Weight Fluctuation (Moved from Common)
                NavigationLink(destination: AnswerView(profile: profile, title: "Weight Fluctuation") {
                    Text("Daily weight can vary due to water retention, salt intake, and digestion. Focus on the 30-day trend line.")
                        .font(.body).padding()
                }) {
                    Text("Why does my weight fluctuate?")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            // MARK: - Section: Workout
            Section(header: Text("Workout")) {
                
                // 1. Add Workouts
                NavigationLink(destination: AnswerView(profile: profile, title: "Adding Workouts") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start a Session")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("You can start a workout from the **Workout Tab**.")
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Empty Workout", desc: "Great for spontaneous sessions. Add exercises as you go.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "From Template", desc: "Select a previous workout from History to copy its exercises.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Text("How to add workouts")
                        .foregroundColor(.primary)
                }
                
                // 2. Exercise Library
                NavigationLink(destination: AnswerView(profile: profile, title: "Exercise Library") {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Managing Exercises")
                                .font(.title2).bold().foregroundColor(.blue)
                            Text("RepScale comes with a built-in database, but you can create your own.")
                        }
                        StepCard(num: 1, title: "Create Custom", desc: "Go to Workout > Library (top left) > + Button.", bg: formulaBoxColor)
                        StepCard(num: 2, title: "Filters", desc: "Filter by muscle group (e.g., Chest, Back) to find exercises quickly.", bg: formulaBoxColor)
                    }
                }) {
                    Text("Exercise Library")
                        .foregroundColor(.primary)
                }
                
                // 3. View History
                NavigationLink(destination: AnswerView(profile: profile, title: "Workout History") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Your entire training log is saved automatically.")
                        StepCard(num: 1, title: "Access History", desc: "Tap the 'History' tab within the Workout view.", bg: formulaBoxColor)
                        StepCard(num: 2, title: "Calendar View", desc: "See which days you trained and tap a date to view details.", bg: formulaBoxColor)
                    }
                }) {
                    Text("How to view workout history")
                        .foregroundColor(.primary)
                }
                
                // 4. Muscle Recovery
                NavigationLink(destination: AnswerView(profile: profile, title: "Muscle Recovery") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Recovery Tracking")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("The dashboard displays a muscle heatmap. Muscles you trained recently appear **Red** (recovering) and turn **Green** (ready) over time.")
                    }
                }) {
                    Text("Tracking muscle recovery")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            // MARK: - Section: RepScale Premium
            Section(header: Text("RepScale Premium")) {
                
                // 1. Premium Dashboard Views
                NavigationLink(destination: AnswerView(profile: profile, title: "Dashboard Views") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Advanced Insights")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Unlock powerful visualizations to track your progress at a glance.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Muscle Heatmap", desc: "Visualize which muscles are recovering (Red) vs ready to train (Green).", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Macro Trends", desc: "See your Protein, Carb, and Fat intake averages over the last 7 days.", bg: formulaBoxColor)
                            StepCard(num: 3, title: "Extended Charts", desc: "View weight and calorie trends over 3 months, 6 months, or 1 year.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("Premium Dashboard Views", systemImage: "chart.bar.fill")
                        .foregroundColor(.primary)
                }
                
                // 2. Custom Workout Templates
                NavigationLink(destination: AnswerView(profile: profile, title: "Workout Templates") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Unlimited Routines")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Save as many workout routines as you need (e.g., Push A, Pull B, Leg Day).")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to create:")
                                .font(.headline)
                            StepCard(num: 1, title: "Create", desc: "Go to the Workout Tab > Tap '+ Add Workout'.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Save", desc: "Add your exercises, then tap 'Save as Template' in the top right menu.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("Custom Workout Templates", systemImage: "list.clipboard.fill")
                        .foregroundColor(.primary)
                }
                
                // 3. Add Progress Photos
                NavigationLink(destination: AnswerView(profile: profile, title: "Progress Photos") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Visual Tracking")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Securely attach photos to your weight logs to track physical changes alongside the scale number.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to add:")
                                .font(.headline)
                            StepCard(num: 1, title: "Log Weight", desc: "Go to the Weight Tab and tap the + button.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Attach", desc: "Tap the Camera icon to take a photo or choose from your library.", bg: formulaBoxColor)
                        }
                        Text("Note: Photos are stored locally on your device/iCloud and are never shared.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }) {
                    Label("Add Progress Photos", systemImage: "camera.fill")
                        .foregroundColor(.primary)
                }
                
                // 4. View Unlimited Log History
                NavigationLink(destination: AnswerView(profile: profile, title: "Log History") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Full Archives")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Access your entire training and nutrition history from Day 1.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Calendar", desc: "Scroll back indefinitely in the Calendar view to see past workouts.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Analysis", desc: "Compare your current strength levels to where you started months or years ago.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("View Unlimited Log History", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
                
                // 5. Detailed Apple HealthKit Nutrition
                NavigationLink(destination: AnswerView(profile: profile, title: "Macro Sync") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Beyond Calories")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Sync detailed macronutrient data (Protein, Fats, Carbs) from apps like MyFitnessPal, Cronometer, or LoseIt!.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Setup", desc: "Enable 'HealthKit Sync' in Settings > Tracking.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Permissions", desc: "Ensure RepScale has permission to read Protein, Fat, and Carbohydrates in iOS Health Settings.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("Detailed HealthKit Nutrition", systemImage: "heart.text.square.fill")
                        .foregroundColor(.primary)
                }
                
                // 6. Custom Muscle Groups
                NavigationLink(destination: AnswerView(profile: profile, title: "Custom Muscles") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Specific Targeting")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Define your own target areas to better organize your custom exercises.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Define", desc: "Create tags like 'Upper Chest' or 'Rear Delts' instead of generic groups.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Filter", desc: "Filter your Exercise Library by these custom groups to find movements faster.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("Custom Muscle Groups", systemImage: "figure.arms.open")
                        .foregroundColor(.primary)
                }
                
                // 7. Export Data to CSV
                NavigationLink(destination: AnswerView(profile: profile, title: "Data Export") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Data Ownership")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Download your entire database in a standard CSV format compatible with Excel or Google Sheets.")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepCard(num: 1, title: "Export", desc: "Go to Settings > Data Management.", bg: formulaBoxColor)
                            StepCard(num: 2, title: "Share", desc: "Tap 'Export to CSV' and choose where to save or send the file.", bg: formulaBoxColor)
                        }
                    }
                }) {
                    Label("Export Data to CSV", systemImage: "square.and.arrow.up.fill")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
        }
    }
}

// MARK: - Helper Views

// 1. Generic Answer Screen
struct AnswerView<Content: View>: View {
    var profile: UserProfile
    let title: String
    @ViewBuilder let content: Content
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var body: some View {
        ScrollView {
            content
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(appBackgroundColor)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 2. Reusable Step Card Component
struct StepCard: View {
    let num: Int
    let title: String
    let desc: String
    let bg: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .cornerRadius(12)
    }
}
