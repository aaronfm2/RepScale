// RepScale/Managers/SubscriptionManager.swift
import Foundation
import SwiftUI
import RevenueCat
import RevenueCatUI

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false
    @Published var customerInfo: CustomerInfo?
    
    private override init() {
        super.init()
        // REMOVED: Purchases.shared.delegate = self
        // accessing .shared here caused the crash!
    }
    
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_WwzTFIleIfueSHdlAUKncZzTYrc")
        
        // NOW it is safe to access .shared
        Purchases.shared.delegate = self
        
        // Fetch initial status
        Task {
            await refreshCustomerInfo()
        }
    }
    
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.updateProStatus(with: info)
        } catch {
            print("Error fetching customer info: \(error)")
        }
    }
    
    private func updateProStatus(with info: CustomerInfo) {
        self.customerInfo = info
        // Check if the 'pro' entitlement is active
        self.isPro = info.entitlements["pro"]?.isActive == true
    }
}

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(with: customerInfo)
    }
}
