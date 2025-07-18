//
//  IntegrityError.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation

enum IntegrityError: Error, LocalizedError {
    case appAttestNotSupported
    case keyGenerationFailed
    case attestationFailed
    case assertionFailed
    case keyNotFound
    case invalidChallenge
    case serverError(String)
    case certificateParsingFailed
    case certificateStorageFailed
    case certificateNotFound
    
    var errorDescription: String? {
        switch self {
        case .appAttestNotSupported:
            return "App Attest 不支持此设备"
        case .keyGenerationFailed:
            return "密钥生成失败"
        case .attestationFailed:
            return "设备认证失败"
        case .assertionFailed:
            return "断言生成失败"
        case .keyNotFound:
            return "未找到密钥"
        case .invalidChallenge:
            return "无效的质询数据"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .certificateParsingFailed:
            return "证书解析失败"
        case .certificateStorageFailed:
            return "证书存储失败"
        case .certificateNotFound:
            return "未找到证书"
        }
    }
}