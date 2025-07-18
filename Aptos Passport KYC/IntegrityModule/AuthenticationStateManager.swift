//
//  AuthenticationStateManager.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import Combine
import DeviceCheck

/// 认证状态管理器 - 检查设备Secure Enclave中的密钥状态
@MainActor
class AuthenticationStateManager: ObservableObject {
    static let shared = AuthenticationStateManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var lastKeyId: String?
    @Published var keyCheckDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let keyIdKey = "aptos_passport_kyc_last_key_id"
    
    private init() {
        // 延迟检查，避免初始化时的循环依赖
        Task {
            await checkAuthenticationStateAsync()
        }
    }
    
    // MARK: - Public Methods
    
    /// 记录新的认证密钥ID
    func recordAuthentication(keyId: String) {
        lastKeyId = keyId
        isAuthenticated = true
        keyCheckDate = Date()
        
        // 只保存密钥ID，用于后续检查
        userDefaults.set(keyId, forKey: keyIdKey)
        
        print("✅ 认证状态已记录")
        print("   - Key ID: \(keyId)")
        print("   - 记录时间: \(Date())")
    }
    
    /// 异步检查认证状态
    func checkAuthenticationStateAsync() async {
        await MainActor.run {
            print("🔍 开始检查设备认证状态...")
        }
        
        // 检查是否支持App Attest
        guard DCAppAttestService.shared.isSupported else {
            await MainActor.run {
                print("❌ 设备不支持App Attest")
                isAuthenticated = false
                lastKeyId = nil
            }
            return
        }
        
        // 获取上次保存的密钥ID
        let savedKeyId = userDefaults.string(forKey: keyIdKey)
        
        await MainActor.run {
            if let keyId = savedKeyId {
                print("📱 找到已保存的密钥ID: \(keyId)")
                lastKeyId = keyId
                isAuthenticated = true
                keyCheckDate = Date()
                
                // 同步更新AppAttestService的状态
                AppAttestService.shared.lastKeyId = keyId
                // 注意：这里我们没有attestation数据，但有keyId就足够判断已认证状态
                
                print("✅ 认证状态检查完成: 已认证")
                print("   - Key ID: \(keyId)")
                print("   - 检查时间: \(Date())")
                print("   - AppAttestService状态已同步")
            } else {
                print("📱 未找到已保存的密钥ID")
                isAuthenticated = false
                lastKeyId = nil
                print("✅ 认证状态检查完成: 未认证")
            }
        }
    }
    
    /// 清除认证状态
    func clearAuthenticationState() {
        userDefaults.removeObject(forKey: keyIdKey)
        lastKeyId = nil
        isAuthenticated = false
        keyCheckDate = nil
        
        // 同步清除AppAttestService的状态
        AppAttestService.shared.lastKeyId = nil
        AppAttestService.shared.lastAttestation = nil
        
        print("🧹 认证状态已清除")
        print("   - UserDefaults中的密钥ID已移除")
        print("   - AppAttestService状态已清除")
    }
    
    /// 强制重新检查认证状态
    func refreshAuthenticationState() {
        Task {
            await checkAuthenticationStateAsync()
        }
    }
    
    /// 获取认证状态摘要信息
    func getAuthenticationSummary() -> String {
        guard isAuthenticated, let keyId = lastKeyId else {
            return "未认证"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let checkDateString = keyCheckDate.map { formatter.string(from: $0) } ?? "未知"
        
        return """
        认证状态: 已认证
        检查时间: \(checkDateString)
        Key ID: \(keyId.prefix(8))...
        """
    }
}
