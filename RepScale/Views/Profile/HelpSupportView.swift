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
            Section(header: Text("Common Questions")) {
                
                // MARK: - Maintenance Estimation
                NavigationLink(destination: AnswerView(profile: profile, title: "Maintenance Estimation") {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // --- Formula Estimate Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Formula Estimate")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.blue)
                            
                            Text("This is a theoretical estimate based on the **Mifflin-St Jeor** equation multiplied by your activity level.")
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Formula Card
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BMR = (10 × weight) + (6.25 × height) - (5 × age) + s")
                                    .font(.system(.callout, design: .monospaced))
                                    .fontWeight(.medium)
                                
                                Text("*(s = +5 for men, -161 for women)*")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(formulaBoxColor)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            Text("This BMR is then multiplied by your selected Activity Level:")
                                .font(.subheadline)
                                .padding(.top, 4)
                            
                            // Multipliers Grid
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                GridRow {
                                    Text("• Sedentary")
                                    Text("x 1.2").font(.system(.body, design: .monospaced))
                                }
                                GridRow {
                                    Text("• Lightly Active")
                                    Text("x 1.375").font(.system(.body, design: .monospaced))
                                }
                                GridRow {
                                    Text("• Active")
                                    Text("x 1.55").font(.system(.body, design: .monospaced))
                                }
                                GridRow {
                                    Text("• Very Active")
                                    Text("x 1.725").font(.system(.body, design: .monospaced))
                                }
                            }
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        }
                        
                        Divider()
                        
                        // --- App Estimate Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("App Estimate")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.blue)
                            
                            Text("This is your **True Maintenance**, calculated by analyzing your actual data over the last 30 days. It compares how much you ate versus how much your weight changed.")
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Maintenance = Avg. Intake - Daily Surplus")
                                .font(.system(.callout, design: .monospaced))
                                .padding(.vertical, 2)
                            
                            Text("The Daily Surplus is calculated using the standard conversion where **7700 kcal ≈ 1kg** of body weight:")
                                .font(.subheadline)
                            
                            // Formula Card
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Surplus =")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text("(Weight Change (kg) × 7700) / 30 Days")
                                    .font(.system(.callout, design: .monospaced))
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(formulaBoxColor)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }) {
                    Text("How are maintenance calories estimated?")
                        .foregroundColor(.primary)
                }
                
                // MARK: - Weight Fluctuation
                NavigationLink(destination: AnswerView(profile: profile, title: "Weight Fluctuation") {
                    Text("Daily weight can vary due to water retention, salt intake, and digestion. Focus on the 30-day trend line.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }) {
                    Text("Why does my weight fluctuate?")
                        .foregroundColor(.primary)
                }
                
                // MARK: - HealthKit Sync
                NavigationLink(destination: AnswerView(profile: profile, title: "HealthKit Sync") {
                    Text("Yes! We pull Active Energy and Dietary Energy from Apple Health automatically. You can also add manual entries.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }) {
                    Text("Does it sync with HealthKit?")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(cardBackgroundColor)
            
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

// MARK: - AnswerView
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
