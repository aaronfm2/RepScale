import SwiftUI

struct HelpSupportView: View {
    var profile: UserProfile
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }

    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var body: some View {
        Form {
            Section(header: Text("Common Questions")) {
                NavigationLink(destination: AnswerView(
                    profile: profile,
                    title: "Maintenance Estimation",
                    text: "We analyze your weight changes and calorie intake over the last 30 days to calculate your true maintenance level."
                )) {
                    Text("How is maintenance estimated?")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: AnswerView(
                    profile: profile,
                    title: "Weight Fluctuation",
                    text: "Daily weight can vary due to water retention, salt intake, and digestion. Focus on the 30-day trend line."
                )) {
                    Text("Why does my weight fluctuate?")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: AnswerView(
                    profile: profile,
                    title: "HealthKit Sync",
                    text: "Yes! We pull Active Energy and Dietary Energy from Apple Health automatically. You can also add manual entries."
                )) {
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

// Helper view to display the answer on a new screen
struct AnswerView: View {
    var profile: UserProfile
    let title: String
    let text: String
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(appBackgroundColor)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
