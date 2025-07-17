//
//  AppAttest.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/17.
//


import DeviceCheck
import CryptoKit

/// Possible errors from AttestationManager
enum AttestationError: Error {
    /// The current device / iOS version does not support App Attest
    case unsupportedDevice
}

/// Mocked AttestationManager — provides the same interface expected by ContentView
/// Replace this with a real implementation once server APIs are ready.
final class AttestationManager {
    static let shared = AttestationManager()
    private init() {}
    
    /// Returns `true` when App Attest is available on this device (iOS 14+ real device, not Simulator).
    static var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }
    
    /// Mimics the async prepare flow and returns a placeholder keyID
    func prepare() async throws -> String {
        guard Self.isSupported else { throw AttestationError.unsupportedDevice }
        // Simulate some async work (e.g., Secure Enclave or network call)
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s delay
        return "MOCK-KEYID-123456"
    }
}
