import SwiftUI

struct HelpSupportView: View {
    var body: some View {
        List {
            Section(header: Text("Common Questions")) {
                DisclosureGroup("How is maintenance estimated?") {
                    Text("We analyze your weight changes and calorie intake over the last 30 days to calculate your true maintenance level.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                DisclosureGroup("Why does my weight fluctuate?") {
                    Text("Daily weight can vary due to water retention, salt intake, and digestion. Focus on the 30-day trend line.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                DisclosureGroup("Does it sync with HealthKit?") {
                    Text("Yes! We pull Active Energy and Dietary Energy from Apple Health automatically. You can also add manual entries.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Contact")) {
                if let url = URL(string: "mailto:feedback@repscale.app") {
                    Link(destination: url) {
                        Label("Email Support", systemImage: "envelope")
                    }
                }
            }
        }
        .navigationTitle("Help & Support")
    }
}
