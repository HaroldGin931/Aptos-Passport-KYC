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
            print("🔄 ========== App Assert 流程开始 ==========")
            print("📋 第二阶段：后续通信（App Assert）")
            print("💡 前提条件: 设备已通过App Attest认证，服务器已保存公钥")
            
            print("\n📝 步骤1: 准备敏感数据...")
            print("� 使用Key ID: \(keyId)")
            print("📦 敏感数据大小: \(requestData.count) bytes")
            print("📄 敏感数据内容: \(String(data: requestData.prefix(100), encoding: .utf8) ?? "Binary data")...")
            
            print("\n🔒 步骤2: 对敏感数据进行哈希...")
            let requestDataHash = SHA256.hash(data: requestData)
            let requestDataHashData = Data(requestDataHash)
            print("� SHA256哈希: \(requestDataHashData.base64EncodedString())")
            print("💡 哈希确保数据完整性，防止传输过程中被篡改")
            
            print("\n✍️  步骤3: 使用设备私钥对哈希进行签名...")
            print("🔐 调用设备安全区域进行签名...")
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: requestDataHashData)
            
            lastAssertion = assertion
            
            print("✅ 签名生成成功!")
            print("📋 签名详情:")
            print("   - 签名大小: \(assertion.count) bytes")
            print("   - 签名方式: ECDSA (椭圆曲线数字签名)")
            print("   - 私钥位置: 设备安全区域 (无法导出)")
            print("   - 包含信息: 数据签名 + 计数器 + 认证数据")
            
            print("\n🚀 步骤4: 准备发送到服务器...")
            print("📤 完整请求包含:")
            print("   1. 原始敏感数据")
            print("   2. 数据签名 (assertion)")
            print("   3. Key ID (标识使用的密钥)")
            
            print("\n🔍 服务器验证流程:")
            print("   1. 根据Key ID找到对应的公钥")
            print("   2. 对原始数据进行SHA256哈希")
            print("   3. 使用公钥验证签名")
            print("   4. 检查计数器防止重放攻击")
            print("   5. 验证通过后处理敏感数据")
            
            print("🎯 ========== App Assert 流程完成 ==========\n")
            
            isLoading = false
            return assertion
            
        } catch {
            isLoading = false
            let detailedError = "App Assert failed: \(error.localizedDescription)"
            print("❌ App Assert 失败: \(detailedError)")
            
            if let dcError = error as? DCError {
                switch dcError.code {
                case .featureUnsupported:
                    errorMessage = "App Assert 不支持"
                    print("❌ 错误原因: 设备不支持App Assert功能")
                case .invalidInput:
                    errorMessage = "无效的数据输入"
                    print("❌ 错误原因: 提供的数据格式无效")
                case .invalidKey:
                    errorMessage = "无效的密钥 - 密钥可能未经认证"
                    print("❌ 错误原因: 使用的Key ID未经过App Attest认证")
                case .serverUnavailable:
                    errorMessage = "Apple服务不可用"
                    print("❌ 错误原因: Apple的App Attest服务暂时不可用")
                default:
                    errorMessage = "App Assert 错误: \(dcError.localizedDescription)"
                    print("❌ 其他错误: \(dcError.localizedDescription)")
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
                    "stage": "第二阶段：后续通信（App Assert）",
                    "purpose": "使用已认证的设备密钥对敏感数据进行签名",
                    "prerequisite": "设备必须已通过App Attest认证，服务器已保存对应公钥"
                },
                "assertion_contains": [
                    "敏感数据的数字签名",
                    "计数器（防重放攻击）",
                    "认证数据",
                    "时间戳信息"
                ],
                "server_verification_process": [
                    "1. 根据key_id查找对应的公钥",
                    "2. 对request_data进行SHA256哈希",
                    "3. 使用公钥验证assertion签名",
                    "4. 检查计数器是否递增",
                    "5. 验证时间戳有效性",
                    "6. 确认数据完整性后处理请求"
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
