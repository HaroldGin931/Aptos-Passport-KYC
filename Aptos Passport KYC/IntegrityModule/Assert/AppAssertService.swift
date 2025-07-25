//
//  AppAssertService.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import DeviceCheck
import CryptoKit
import Combine

@MainActor
class AppAssertService: ObservableObject {
    static let shared = AppAssertService()
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastAssertion: Data?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func generateAssertion(keyId: String, requestData: Data) async throws -> Data {
        guard DCAppAttestService.shared.isSupported else {
            throw IntegrityError.appAttestNotSupported
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 ========== App Assert Process Started ==========")
            print("📋 Stage 2: Subsequent Communication (App Assert)")
            print("💡 Prerequisites: Device has passed App Attest authentication, server has saved public key")
            
            print("\n📝 Step 1: Prepare sensitive data...")
            print("🔑 Using Key ID: \(keyId)")
            print("📦 Sensitive data size: \(requestData.count) bytes")
            print("📄 Sensitive data content: \(String(data: requestData.prefix(100), encoding: .utf8) ?? "Binary data")...")
            
            print("\n🔒 Step 2: Hash sensitive data...")
            let requestDataHash = SHA256.hash(data: requestData)
            let requestDataHashData = Data(requestDataHash)
            print("🔐 SHA256 hash: \(requestDataHashData.base64EncodedString())")
            print("💡 Hash ensures data integrity, preventing tampering during transmission")
            
            print("\n✍️  Step 3: Sign hash using device private key...")
            print("🔐 Calling device secure enclave for signing...")
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: requestDataHashData)
            
            lastAssertion = assertion
            
            print("✅ Signature generated successfully!")
            print("📋 Signature details:")
            print("   - Signature size: \(assertion.count) bytes")
            print("   - Signature method: ECDSA (Elliptic Curve Digital Signature)")
            print("   - Private key location: Device secure enclave (cannot be exported)")
            print("   - Included information: Data signature + Counter + Authentication data")
            
            print("\n🚀 Step 4: Prepare to send to server...")
            print("📤 Complete request contains:")
            print("   1. Original sensitive data")
            print("   2. Data signature (assertion)")
            print("   3. Key ID (identifies the key used)")
            
            print("\n🔍 Server verification process:")
            print("   1. Find corresponding public key based on Key ID")
            print("   2. Perform SHA256 hash on original data")
            print("   3. Verify signature using public key")
            print("   4. Check counter to prevent replay attacks")
            print("   5. Process sensitive data after successful verification")
            
            print("🎯 ========== App Assert Process Complete ==========\n")
            
            isLoading = false
            return assertion
            
        } catch {
            isLoading = false
            let detailedError = "App Assert failed: \(error.localizedDescription)"
            print("❌ App Assert failed: \(detailedError)")
            
            if let dcError = error as? DCError {
                switch dcError.code {
                case .featureUnsupported:
                    errorMessage = "App Assert not supported"
                    print("❌ Error reason: Device does not support App Assert feature")
                case .invalidInput:
                    errorMessage = "Invalid data input"
                    print("❌ Error reason: Provided data format is invalid")
                case .invalidKey:
                    errorMessage = "Invalid key - Key may not be authenticated"
                    print("❌ Error reason: Used Key ID has not passed App Attest authentication")
                case .serverUnavailable:
                    errorMessage = "Apple service unavailable"
                    print("❌ Error reason: Apple's App Attest service is temporarily unavailable")
                default:
                    errorMessage = "App Assert error: \(dcError.localizedDescription)"
                    print("❌ Other error: \(dcError.localizedDescription)")
                }
            } else {
                errorMessage = detailedError
            }
            
            throw IntegrityError.attestationFailed
        }
    }
    
    // MARK: - Convenience Methods
    
    func assertSensitiveRequest(keyId: String, requestPayload: [String: Any]) async throws -> Data {
        // Convert request payload to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: .sortedKeys)
        return try await generateAssertion(keyId: keyId, requestData: jsonData)
    }
    
    func assertStringRequest(keyId: String, requestString: String) async throws -> Data {
        let requestData = requestString.data(using: .utf8) ?? Data()
        return try await generateAssertion(keyId: keyId, requestData: requestData)
    }
    
    // MARK: - Helper Methods
    
    func createAssertionPackage(keyId: String, assertion: Data, originalRequest: Data) -> [String: Any] {
        return [
            "keyId": keyId,
            "assertion": assertion.base64EncodedString(),
            "originalRequest": originalRequest.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970,
            "bundleId": Bundle.main.bundleIdentifier ?? "unknown"
        ]
    }
    
    func saveAssertionToFile(assertion: Data, keyId: String, requestData: Data) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: Date())
        
        let assertionContent = """
        {
            "app_assert_data": {
                "generated_at": "\(dateString)",
                "key_id": "\(keyId)",
                "bundle_id": "\(Bundle.main.bundleIdentifier ?? "unknown")",
                "assertion_base64": "\(assertion.base64EncodedString())",
                "assertion_size": \(assertion.count),
                "request_data_base64": "\(requestData.base64EncodedString())",
                "request_data_size": \(requestData.count),
                "request_data_preview": "\(String(data: requestData.prefix(100), encoding: .utf8) ?? "Binary data")...",
                "flow_info": {
                    "stage": "Stage 2: Subsequent Communication (App Assert)",
                    "purpose": "Use authenticated device key to sign sensitive data",
                    "prerequisite": "Device must have passed App Attest authentication, server has saved corresponding public key"
                },
                "assertion_contains": [
                    "Digital signature of sensitive data",
                    "Counter (prevent replay attacks)",
                    "Authentication data",
                    "Timestamp information"
                ],
                "server_verification_process": [
                    "1. Find corresponding public key based on key_id",
                    "2. Perform SHA256 hash on request_data",
                    "3. Verify assertion signature using public key",
                    "4. Check if counter is incremented",
                    "5. Verify timestamp validity",
                    "6. Process request after confirming data integrity"
                ],
                "security_benefits": [
                    "数据完整性：确保传输数据未被篡改",
                    "身份认证：证明请求来自已认证的设备",
                    "防重放攻击：计数器机制防止请求重复使用",
                    "不可否认性：设备无法否认发送过此请求"
                ],
                "poc_note": "此为POC演示，展示App Attest + App Assert完整流程"
            }
        }
        """
        
        return assertionContent
    }
}
