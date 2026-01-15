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
            
            // MARK: - Section: Premium Features
            Section(header: Text("RepScale Premium")) {
                
                // 1. Data Export
                NavigationLink(destination: AnswerView(profile: profile, title: "Data Export") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Data Ownership")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Premium users can export their entire database to CSV format for use in Excel or other tools.")
                    }
                }) {
                    Label("Data Export (CSV)", systemImage: "star.fill")
                        .foregroundColor(.primary)
                }
                
                // 2. Advanced Analytics
                NavigationLink(destination: AnswerView(profile: profile, title: "Advanced Analytics") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Deep Insights")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Unlock extended time ranges (90 days, 1 Year, All Time) for weight trends and strength progression graphs.")
                    }
                }) {
                    Label("Advanced Analytics", systemImage: "star.fill")
                        .foregroundColor(.primary)
                }
                
                // 3. Unlimited Routines
                NavigationLink(destination: AnswerView(profile: profile, title: "Unlimited Logging") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("No Limits")
                            .font(.title2).bold().foregroundColor(.blue)
                        Text("Remove all restrictions on the number of saved workout templates and custom exercises.")
                    }
                }) {
                    Label("Unlimited Templates", systemImage: "star.fill")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            // MARK: - Section: Contact
            Section(header: Text("Contact")) {
                if let url = URL(string: "mailto:feedback@repscale.app") {
                    Link(destination: url) {
                        Label("Email Support", systemImage: "envelope")
                            .foregroundColor(.primary)
                    }
                }
            }
            .listRowBackground(cardBackgroundColor)
        }
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
        .navigationTitle("Help & Support")
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
