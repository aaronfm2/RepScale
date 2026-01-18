//
//  PremiumView.swift
//  RepScale
//
//  Created by Aaron Franklin-Martinez on 18/01/2026.
//


import SwiftUI
import RevenueCat

struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    var appBackgroundColor: Color
    
    // MARK: - State
    enum SubscriptionPeriod { case yearly, monthly, lifetime }
    @State private var selectedPeriod: SubscriptionPeriod = .yearly
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showBrowserAlert = false
    
    // MARK: - RevenueCat Data
    @State private var offering: Offering?
    
    // Computed Packages
    private var monthlyPackage: Package? { offering?.monthly }
    private var yearlyPackage: Package? { offering?.annual }
    private var lifetimePackage: Package? { offering?.lifetime }
    
    // Get Selected Package
    private var selectedPackage: Package? {
        switch selectedPeriod {
        case .monthly: return monthlyPackage
        case .yearly: return yearlyPackage
        case .lifetime: return lifetimePackage
        }
    }

    var body: some View {
        ZStack {
            // Background
            appBackgroundColor.ignoresSafeArea()
            
            // 1. Scrollable Content
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
                        
                        // Feature List
                        VStack(spacing: 0) {
                            HStack {
                                Text("Features").font(.footnote.bold()).foregroundStyle(.secondary)
                                Spacer()
                                Text("Free").font(.footnote.bold()).foregroundStyle(.secondary).frame(width: 50)
                                Text("Pro").font(.footnote.bold()).foregroundStyle(.blue).frame(width: 50)
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
                                FeatureRow(name: "Detailed Apple HealthKit", free: false, premium: true)
                                FeatureRow(name: "Export Data to CSV", free: false, premium: true)
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        
                        Color.clear.frame(height: 250) // Spacer for footer
                    }
                }
            }
            
            // 2. Fixed Bottom Sheet
            if let offering = offering {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 16) {
                        
                        // Plan Selection
                        HStack(spacing: 8) {
                            // Monthly
                            if let monthly = monthlyPackage {
                                PlanSelectionCard(
                                    title: "Monthly",
                                    price: monthly.storeProduct.localizedPriceString,
                                    subtitle: "/mo",
                                    isSelected: selectedPeriod == .monthly,
                                    badge: nil
                                )
                                .onTapGesture { withAnimation { selectedPeriod = .monthly } }
                            }
                            
                            // Yearly
                            if let yearly = yearlyPackage {
                                PlanSelectionCard(
                                    title: "Yearly",
                                    price: yearly.storeProduct.localizedPriceString,
                                    subtitle: "/yr",
                                    isSelected: selectedPeriod == .yearly,
                                    badge: "BEST VALUE"
                                )
                                .onTapGesture { withAnimation { selectedPeriod = .yearly } }
                            }
                            
                            // Lifetime
                            if let lifetime = lifetimePackage {
                                PlanSelectionCard(
                                    title: "Lifetime",
                                    price: lifetime.storeProduct.localizedPriceString,
                                    subtitle: "/once",
                                    isSelected: selectedPeriod == .lifetime,
                                    badge: "FOREVER"
                                )
                                .onTapGesture { withAnimation { selectedPeriod = .lifetime } }
                            }
                        }
                        
                        // Purchase Button
                        Button(action: {
                            performPurchase()
                        }) {
                            ZStack {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(ctaText)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isPurchasing)
                        
                        // Footer Links
                        HStack(spacing: 16) {
                            Button("Restore Purchases") { restorePurchases() }
                            Text("•")
                            Text(selectedPeriod == .lifetime ? "One-time payment" : "Auto-renewable")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } else {
                // Loading State
                ProgressView()
            }
        }
        .task {
            await fetchOfferings()
        }
        .alert(isPresented: $showBrowserAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Logic
    
    var ctaText: String {
        guard let pkg = selectedPackage else { return "Loading..." }
        
        // Introductory offer check (Free Trial)
        if let intro = pkg.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            let days = intro.subscriptionPeriod.value
            // e.g. "Start 7-Day Free Trial"
            return "Start \(days)-Day Free Trial"
        }
        
        return "Subscribe for \(pkg.storeProduct.localizedPriceString)"
    }
    
    func fetchOfferings() async {
        do {
            self.offering = try await Purchases.shared.offerings().current
        } catch {
            print("Error fetching offerings: \(error)")
        }
    }
    
    func performPurchase() {
        guard let pkg = selectedPackage else { return }
        isPurchasing = true
        
        Purchases.shared.purchase(package: pkg) { transaction, customerInfo, error, userCancelled in
            isPurchasing = false
            
            if let error = error {
                if !userCancelled {
                    self.errorMessage = error.localizedDescription
                    self.showBrowserAlert = true
                }
            } else if customerInfo?.entitlements["pro"]?.isActive == true {
                // Success!
                dismiss()
            }
        }
    }
    
    func restorePurchases() {
        isPurchasing = true
        Purchases.shared.restorePurchases { customerInfo, error in
            isPurchasing = false
            if customerInfo?.entitlements["pro"]?.isActive == true {
                dismiss()
            } else {
                self.errorMessage = "No active subscription found to restore."
                self.showBrowserAlert = true
            }
        }
    }
}

// MARK: - Helper Components
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
                    Text(price).font(.system(size: 16, weight: .bold)) // Adjusted font for fit
                    Text(subtitle).font(.caption2).foregroundColor(.secondary)
                }
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                
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
                    .padding(6)
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