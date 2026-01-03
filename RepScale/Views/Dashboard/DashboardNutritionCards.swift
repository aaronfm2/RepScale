import SwiftUI

// Currently empty, ready for future Nutrition-related dashboard cards.
struct NutritionPlaceholderCard: View {
    var body: some View {
        Text("Nutrition Cards (Coming Soon)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}
