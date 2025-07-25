//
//  AuthenticationStateManager.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import Combine
import DeviceCheck

/// Authentication state manager - Check device Secure Enclave key status
@MainActor
class AuthenticationStateManager: ObservableObject {
    static let shared = AuthenticationStateManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var lastKeyId: String?
    @Published var keyCheckDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let keyIdKey = "aptos_passport_kyc_last_key_id"
    
    private init() {
        // Delayed check to avoid circular dependencies during initialization
        Task {
            await checkAuthenticationStateAsync()
        }
    }
    
    // MARK: - Public Methods
    
    /// Record new authentication key ID
    func recordAuthentication(keyId: String) {
        lastKeyId = keyId
        isAuthenticated = true
        keyCheckDate = Date()
        
        // Only save key ID for subsequent checking
        userDefaults.set(keyId, forKey: keyIdKey)
        
        print("✅ Authentication status recorded")
        print("   - Key ID: \(keyId)")
        print("   - Recording time: \(Date())")
    }
    
    /// Asynchronously check authentication status
    func checkAuthenticationStateAsync() async {
        await MainActor.run {
            print("🔍 Starting device authentication status check...")
        }
        
        // Check if App Attest is supported
        guard DCAppAttestService.shared.isSupported else {
            await MainActor.run {
                print("❌ Device does not support App Attest")
                isAuthenticated = false
                lastKeyId = nil
            }
            return
        }
        
        // Get previously saved key ID
        let savedKeyId = userDefaults.string(forKey: keyIdKey)
        
        await MainActor.run {
            if let keyId = savedKeyId {
                print("📱 Found saved key ID: \(keyId)")
                lastKeyId = keyId
                isAuthenticated = true
                keyCheckDate = Date()
                
                // Synchronously update AppAttestService status
                AppAttestService.shared.lastKeyId = keyId
                // Note: We don't have attestation data here, but having keyId is sufficient to determine authenticated status
                
                print("✅ Authentication status check completed: Authenticated")
                print("   - Key ID: \(keyId)")
                print("   - Check time: \(Date())")
                print("   - AppAttestService status synchronized")
            } else {
                print("📱 No saved key ID found")
                isAuthenticated = false
                lastKeyId = nil
                print("✅ Authentication status check completed: Not authenticated")
            }
        }
    }
    
    /// Clear authentication status
    func clearAuthenticationState() {
        userDefaults.removeObject(forKey: keyIdKey)
        lastKeyId = nil
        isAuthenticated = false
        keyCheckDate = nil
        
        // Synchronously clear AppAttestService status
        AppAttestService.shared.lastKeyId = nil
        AppAttestService.shared.lastAttestation = nil
        
        print("🧹 Authentication status cleared")
        print("   - Key ID removed from UserDefaults")
        print("   - AppAttestService status cleared")
    }
    
    /// Force re-check authentication status
    func refreshAuthenticationState() {
        Task {
            await checkAuthenticationStateAsync()
        }
    }
    
    /// Get authentication status summary information
    func getAuthenticationSummary() -> String {
        guard isAuthenticated, let keyId = lastKeyId else {
            return "Not authenticated"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let checkDateString = keyCheckDate.map { formatter.string(from: $0) } ?? "Unknown"
        
        return """
        Authentication status: Authenticated
        Check time: \(checkDateString)
        Key ID: \(keyId.prefix(8))...
        """
    }
}
