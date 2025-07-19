//
//  PassportBACCalculator.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import CryptoKit

/// 护照BAC(Basic Access Control)密钥计算工具类
class PassportBACCalculator {
    
    // MARK: - BAC密钥计算
    
    /// 生成MRZ密钥信息（用于BAC密钥计算）
    /// - Parameters:
    ///   - passportNumber: 护照号
    ///   - dateOfBirth: 出生日期 (YYMMDD格式)
    ///   - dateOfExpiry: 到期日期 (YYMMDD格式)
    /// - Returns: 格式化的MRZ密钥字符串
    static func generateMRZKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> String {
        print("🔹 [BAC Calculator] 开始生成BAC密钥...")
        print("🔹 [BAC Calculator] 输入参数:")
        print("🔹 [BAC Calculator]   护照号: '\(passportNumber)'")
        print("🔹 [BAC Calculator]   出生日期: '\(dateOfBirth)'")
        print("🔹 [BAC Calculator]   到期日期: '\(dateOfExpiry)'")
        
        // 使用新的MRZ生成器生成完整MRZ
        let fullMRZ = PassportMRZGenerator.generateMRZ(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        print("🔹 [BAC Calculator] 完整MRZ已生成:")
        print(fullMRZ.displayFormat)
        
        // 从完整MRZ中提取BAC所需的字符串
        let bacString = PassportMRZGenerator.extractBACString(from: fullMRZ)
        
        print("🔹 [BAC Calculator] BAC密钥: '\(bacString)' (长度: \(bacString.count))")
        
        return bacString
    }
    
    /// 计算BAC种子密钥（Kseed）
    /// - Parameters:
    ///   - passportNumber: 护照号
    ///   - dateOfBirth: 出生日期 (YYMMDD格式)
    ///   - dateOfExpiry: 到期日期 (YYMMDD格式)
    /// - Returns: SHA-1哈希后的种子密钥（前16字节）
    static func calculateBACSeederKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> Data {
        let mrzKey = generateMRZKey(passportNumber: passportNumber, dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
        let mrzData = mrzKey.data(using: .utf8) ?? Data()
        
        print("🔹 [BAC Debug] MRZ密钥数据(字符串): '\(mrzKey)'")
        print("🔹 [BAC Debug] MRZ密钥数据(UTF-8字节): \(mrzData.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 使用SHA-1计算哈希，然后取前16字节作为种子密钥
        let sha1Hash = Data(Insecure.SHA1.hash(data: mrzData))
        let seedKey = Data(sha1Hash.prefix(16))
        
        print("🔹 [BAC Debug] SHA-1完整哈希: \(sha1Hash.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("🔹 [BAC Debug] 种子密钥(前16字节): \(seedKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        return seedKey
    }
    
    /// 使用TR-SAC 1.01标准派生BAC加密和MAC密钥
    /// - Parameters:
    ///   - passportNumber: 护照号
    ///   - dateOfBirth: 出生日期 (YYMMDD格式)
    ///   - dateOfExpiry: 到期日期 (YYMMDD格式)
    /// - Returns: 包含加密和MAC密钥的元组
    static func deriveBACKeys(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> (encryptionKey: Data, macKey: Data) {
        let seedKey = calculateBACSeederKey(passportNumber: passportNumber, dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
        
        // 使用TR-SAC 1.01标准进行密钥派生
        let encryptionKey = deriveKey(from: seedKey, mode: .encryption)
        let macKey = deriveKey(from: seedKey, mode: .mac)
        
        return (encryptionKey, macKey)
    }
    
    /// 调整密钥的奇偶校验位，使其符合DES标准
    /// - Parameter key: 原始密钥
    /// - Returns: 调整奇偶校验位后的密钥
    static func adjustParity(key: Data) -> Data {
        var adjustedKey = Data()
        for byte in key {
            var b = byte
            let parity = (b.nonzeroBitCount % 2 == 0)
            if parity {
                b ^= 1
            }
            adjustedKey.append(b)
        }
        return adjustedKey
    }
    
    // MARK: - 密钥派生（按照TR-SAC 1.01标准）
    
    private enum KeyDerivationMode {
        case encryption
        case mac
        
        var constant: Data {
            switch self {
            case .encryption:
                return Data([0x00, 0x00, 0x00, 0x01]) // Kenc
            case .mac:
                return Data([0x00, 0x00, 0x00, 0x02]) // Kmac
            }
        }
    }
    
    /// 按照TR-SAC 1.01标准派生密钥
    /// - Parameters:
    ///   - seedKey: 16字节的种子密钥
    ///   - mode: 派生模式（加密或MAC）
    /// - Returns: 派生的密钥
    private static func deriveKey(from seedKey: Data, mode: KeyDerivationMode) -> Data {
        // 按照TR-SAC 1.01, 4.2.1进行3DES密钥派生
        let derivationData = seedKey + mode.constant
        
        print("🔹 [BAC Debug] 密钥派生输入 (\(mode == .encryption ? "加密" : "MAC")): \(derivationData.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        let hash = Data(Insecure.SHA1.hash(data: derivationData))
        
        print("🔹 [BAC Debug] 派生哈希: \(hash.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 对于3DES：取前16字节，然后再加上前8字节形成24字节的3DES密钥
        let keyData = Data(hash.prefix(16))
        let expandedKey = keyData + Data(keyData.prefix(8))
        
        print("🔹 [BAC Debug] 最终密钥 (\(mode == .encryption ? "加密" : "MAC")): \(expandedKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        return expandedKey
    }
    
    // MARK: - 格式化和校验辅助方法（保留用于兼容性）
    
    /// 计算校验位（按照ICAO 9303标准）
    /// - Parameter input: 输入字符串
    /// - Returns: 校验位字符
    private static func calculateCheckDigit(_ input: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0
        
        print("🔹 [BAC Debug] 计算校验位 - 输入: '\(input)'")
        
        for (index, char) in input.enumerated() {
            let weight = weights[index % 3]
            var value = 0
            
            if char.isNumber {
                value = char.wholeNumberValue!
            } else if char == "<" {
                value = 0
            } else {
                // 字母转换为数字（A=10, B=11, ..., Z=35）
                let ascii = char.asciiValue ?? 0
                if ascii >= 65 && ascii <= 90 { // A-Z
                    value = Int(ascii - 55)
                }
            }
            
            sum += value * weight
            print("🔹 [BAC Debug]   位置\(index): '\(char)' -> 值=\(value) × 权重=\(weight) = \(value * weight), 累计=\(sum)")
        }
        
        let checkDigit = sum % 10
        print("🔹 [BAC Debug] 校验位计算: 总和=\(sum) % 10 = \(checkDigit)")
        
        return String(checkDigit)
    }
    
    // MARK: - 验证方法
    
    /// 验证BAC输入信息是否有效
    /// - Parameters:
    ///   - passportNumber: 护照号
    ///   - dateOfBirth: 出生日期
    ///   - dateOfExpiry: 到期日期
    /// - Returns: 验证结果
    static func validateBACInputs(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> BACValidationResult {
        var errors: [String] = []
        
        // 验证护照号
        if passportNumber.isEmpty {
            errors.append("护照号不能为空")
        } else if passportNumber.count > 9 {
            errors.append("护照号不能超过9位")
        }
        
        // 验证出生日期
        if dateOfBirth.count != 6 {
            errors.append("出生日期必须是6位数字")
        } else if !dateOfBirth.allSatisfy({ $0.isNumber }) {
            errors.append("出生日期只能包含数字")
        }
        
        // 验证到期日期
        if dateOfExpiry.count != 6 {
            errors.append("到期日期必须是6位数字")
        } else if !dateOfExpiry.allSatisfy({ $0.isNumber }) {
            errors.append("到期日期只能包含数字")
        }
        
        // 验证日期逻辑
        if errors.isEmpty {
            if !isValidDateFormat(dateOfBirth) {
                errors.append("出生日期格式无效")
            }
            if !isValidDateFormat(dateOfExpiry) {
                errors.append("到期日期格式无效")
            }
        }
        
        return BACValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// 验证日期格式是否有效
    /// - Parameter dateString: YYMMDD格式的日期字符串
    /// - Returns: 是否有效
    private static func isValidDateFormat(_ dateString: String) -> Bool {
        guard dateString.count == 6,
              let month = Int(String(dateString.dropFirst(2).prefix(2))),
              let day = Int(String(dateString.suffix(2))) else {
            return false
        }
        
        return month >= 1 && month <= 12 && day >= 1 && day <= 31
    }
}

// MARK: - 数据结构

/// BAC验证结果
struct BACValidationResult {
    let isValid: Bool
    let errors: [String]
}

/// BAC密钥信息
struct BACKeyInfo {
    let passportNumber: String
    let dateOfBirth: String
    let dateOfExpiry: String
    let mrzKey: String
    let seedKey: Data
    let encryptionKey: Data
    let macKey: Data
    
    init(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) {
        self.passportNumber = passportNumber
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
        
        self.mrzKey = PassportBACCalculator.generateMRZKey(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        self.seedKey = PassportBACCalculator.calculateBACSeederKey(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        let derivedKeys = PassportBACCalculator.deriveBACKeys(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        self.encryptionKey = derivedKeys.encryptionKey
        self.macKey = derivedKeys.macKey
    }
    
    /// 获取BAC密钥信息的摘要
    var summary: String {
        return """
        护照号: \(passportNumber)
        出生日期: \(dateOfBirth)
        到期日期: \(dateOfExpiry)
        MRZ密钥: \(mrzKey)
        种子密钥: \(seedKey.bacHexString)
        加密密钥: \(encryptionKey.bacHexString)
        MAC密钥: \(macKey.bacHexString)
        """
    }
}

// MARK: - Data扩展

extension Data {
    /// 将Data转换为十六进制字符串
    var bacHexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
