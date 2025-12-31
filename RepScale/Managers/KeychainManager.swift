import Foundation
import Security

class KeychainManager {
    static let standard = KeychainManager()
    private let service = "com.repscale.app.storage"
    
    // Keys
    private let onboardingKey = "hasCompletedOnboarding"
    private let seedingKey = "hasSeededDefaultExercises"
    
    private init() {}
    
    // MARK: - Onboarding Status
    
    func setOnboardingComplete() {
        save(key: onboardingKey, value: "true")
    }
    
    func isOnboardingComplete() -> Bool {
        return read(key: onboardingKey) == "true"
    }
    
    func clearOnboardingStatus() {
        delete(key: onboardingKey)
    }
    
    // MARK: - Seeding Status
    
    func setSeededDefaultExercises() {
        save(key: seedingKey, value: "true")
    }
    
    func hasSeededDefaultExercises() -> Bool {
        return read(key: seedingKey) == "true"
    }
    
    // MARK: - Core Helpers
    
    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item to avoid duplicates/errors, then add
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
