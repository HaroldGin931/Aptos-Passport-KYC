//
//  PassportMRZGenerator.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/19.
//

import Foundation

/// 护照MRZ(Machine Readable Zone)生成器
/// 按照ICAO 9303标准生成完整的护照MRZ
class PassportMRZGenerator {
    
    // MARK: - MRZ数据结构
    
    struct MRZData {
        let line1: String  // 第一行 (44字符)
        let line2: String  // 第二行 (44字符)
        
        var fullMRZ: String {
            return line1 + line2
        }
        
        var displayFormat: String {
            return """
            第一行: \(line1)
            第二行: \(line2)
            """
        }
    }
    
    struct PassportInfo {
        let documentType: String        // 文档类型 (通常是"P")
        let issuingCountry: String      // 签发国家代码 (3字符，如"CHN")
        let lastName: String            // 姓
        let firstName: String           // 名
        let passportNumber: String      // 护照号
        let nationality: String         // 国籍代码 (3字符，如"CHN")
        let dateOfBirth: String        // 出生日期 (YYMMDD)
        let gender: String             // 性别 ("M"/"F"/"<")
        let dateOfExpiry: String       // 到期日期 (YYMMDD)
        let personalNumber: String?    // 个人号码 (可选)
    }
    
    // MARK: - 公共方法
    
    /// 生成完整的护照MRZ
    /// - Parameter info: 护照信息
    /// - Returns: 完整的MRZ数据
    static func generateMRZ(from info: PassportInfo) -> MRZData {
        let line1 = generateLine1(info: info)
        let line2 = generateLine2(info: info)
        
        print("🔹 [MRZ Generator] 生成完整MRZ:")
        print("🔹 [MRZ Generator] 第一行: '\(line1)'")
        print("🔹 [MRZ Generator] 第二行: '\(line2)'")
        print("🔹 [MRZ Generator] 第一行长度: \(line1.count)")
        print("🔹 [MRZ Generator] 第二行长度: \(line2.count)")
        
        return MRZData(line1: line1, line2: line2)
    }
    
    /// 从护照基本信息生成MRZ (简化版本)
    /// - Parameters:
    ///   - passportNumber: 护照号
    ///   - dateOfBirth: 出生日期 (YYMMDD)
    ///   - dateOfExpiry: 到期日期 (YYMMDD)
    ///   - lastName: 姓 (可选，默认为"UNKNOWN")
    ///   - firstName: 名 (可选，默认为"UNKNOWN")
    /// - Returns: 完整的MRZ数据
    static func generateMRZ(
        passportNumber: String,
        dateOfBirth: String,
        dateOfExpiry: String,
        lastName: String = "UNKNOWN",
        firstName: String = "UNKNOWN"
    ) -> MRZData {
        let info = PassportInfo(
            documentType: "P",
            issuingCountry: "CHN",
            lastName: lastName,
            firstName: firstName,
            passportNumber: passportNumber,
            nationality: "CHN",
            dateOfBirth: dateOfBirth,
            gender: "M",
            dateOfExpiry: dateOfExpiry,
            personalNumber: nil
        )
        
        return generateMRZ(from: info)
    }
    
    // MARK: - 私有方法
    
    /// 生成MRZ第一行
    /// 格式: P<ISSCOUNTRY<LASTNAME<<FIRSTNAME<<<<<<<<<<<<<<<<<<<<<<
    /// 长度: 44字符
    private static func generateLine1(info: PassportInfo) -> String {
        var line1 = ""
        
        // 1. 文档类型 (1字符)
        line1 += info.documentType
        
        // 2. 国家代码标识符 "<" (1字符)
        line1 += "<"
        
        // 3. 签发国家代码 (3字符)
        line1 += formatCountryCode(info.issuingCountry)
        
        // 4. 姓名部分 (39字符)
        let nameField = formatNameField(lastName: info.lastName, firstName: info.firstName, maxLength: 39)
        line1 += nameField
        
        // 确保长度为44字符
        line1 = padToLength(line1, length: 44)
        
        return line1
    }
    
    /// 生成MRZ第二行
    /// 格式: PASSPORTNUMBER<NATIONALITY<YYMMDD<GENDER<YYMMDD<PERSONALNUMBER<<CHECKDIGIT
    /// 长度: 44字符
    private static func generateLine2(info: PassportInfo) -> String {
        var line2 = ""
        
        // 1. 护照号码 (9字符) + 校验位 (1字符)
        let formattedPassportNumber = formatPassportNumber(info.passportNumber)
        let passportCheckDigit = calculateCheckDigit(formattedPassportNumber)
        line2 += formattedPassportNumber + passportCheckDigit
        
        // 2. 国籍代码 (3字符)
        line2 += formatCountryCode(info.nationality)
        
        // 3. 出生日期 (6字符) + 校验位 (1字符)
        let formattedBirthDate = formatDate(info.dateOfBirth)
        let birthCheckDigit = calculateCheckDigit(formattedBirthDate)
        line2 += formattedBirthDate + birthCheckDigit
        
        // 4. 性别 (1字符)
        line2 += formatGender(info.gender)
        
        // 5. 到期日期 (6字符) + 校验位 (1字符)
        let formattedExpiryDate = formatDate(info.dateOfExpiry)
        let expiryCheckDigit = calculateCheckDigit(formattedExpiryDate)
        line2 += formattedExpiryDate + expiryCheckDigit
        
        // 6. 个人号码字段 (14字符)
        let personalNumberField = formatPersonalNumber(info.personalNumber, maxLength: 14)
        line2 += personalNumberField
        
        // 7. 个人号码校验位 (1字符)
        let personalNumberCheckDigit = calculateCheckDigit(personalNumberField)
        line2 += personalNumberCheckDigit
        
        // 8. 总校验位 (1字符) - 对整个第二行的特定部分进行校验
        let overallCheckDigit = calculateOverallCheckDigit(line2: line2, info: info)
        line2 += overallCheckDigit
        
        // 确保长度为44字符
        line2 = padToLength(line2, length: 44)
        
        return line2
    }
    
    // MARK: - 格式化辅助方法
    
    /// 格式化护照号码
    private static func formatPassportNumber(_ passportNumber: String) -> String {
        let cleanNumber = passportNumber.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        if cleanNumber.count >= 9 {
            return String(cleanNumber.prefix(9))
        } else {
            return cleanNumber + String(repeating: "<", count: 9 - cleanNumber.count)
        }
    }
    
    /// 格式化国家代码
    private static func formatCountryCode(_ countryCode: String) -> String {
        let cleanCode = countryCode.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanCode.count >= 3 {
            return String(cleanCode.prefix(3))
        } else {
            return cleanCode + String(repeating: "<", count: 3 - cleanCode.count)
        }
    }
    
    /// 格式化姓名字段
    private static func formatNameField(lastName: String, firstName: String, maxLength: Int) -> String {
        let cleanLastName = lastName.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "<")
        
        let cleanFirstName = firstName.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "<")
        
        // 格式: LASTNAME<<FIRSTNAME
        var nameField = cleanLastName + "<<" + cleanFirstName
        
        // 如果超过最大长度，截断
        if nameField.count > maxLength {
            nameField = String(nameField.prefix(maxLength))
        } else {
            // 用<填充到指定长度
            nameField += String(repeating: "<", count: maxLength - nameField.count)
        }
        
        return nameField
    }
    
    /// 格式化日期
    private static func formatDate(_ date: String) -> String {
        let cleanDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanDate.count == 6 && cleanDate.allSatisfy({ $0.isNumber }) {
            return cleanDate
        } else {
            return "000000"
        }
    }
    
    /// 格式化性别
    private static func formatGender(_ gender: String) -> String {
        let cleanGender = gender.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch cleanGender {
        case "M", "MALE", "男":
            return "M"
        case "F", "FEMALE", "女":
            return "F"
        default:
            return "<"
        }
    }
    
    /// 格式化个人号码字段
    private static func formatPersonalNumber(_ personalNumber: String?, maxLength: Int) -> String {
        guard let personalNumber = personalNumber, !personalNumber.isEmpty else {
            return String(repeating: "<", count: maxLength)
        }
        
        let cleanNumber = personalNumber.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        if cleanNumber.count >= maxLength {
            return String(cleanNumber.prefix(maxLength))
        } else {
            return cleanNumber + String(repeating: "<", count: maxLength - cleanNumber.count)
        }
    }
    
    /// 填充到指定长度
    private static func padToLength(_ string: String, length: Int) -> String {
        if string.count >= length {
            return String(string.prefix(length))
        } else {
            return string + String(repeating: "<", count: length - string.count)
        }
    }
    
    // MARK: - 校验位计算
    
    /// 计算校验位（按照ICAO 9303标准）
    private static func calculateCheckDigit(_ input: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0
        
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
        }
        
        return String(sum % 10)
    }
    
    /// 计算总校验位
    /// 对护照号+校验位+出生日期+校验位+到期日期+校验位+个人号码+校验位进行校验
    private static func calculateOverallCheckDigit(line2: String, info: PassportInfo) -> String {
        // 构建用于总校验的字符串
        let passportPart = formatPassportNumber(info.passportNumber) + calculateCheckDigit(formatPassportNumber(info.passportNumber))
        let birthPart = formatDate(info.dateOfBirth) + calculateCheckDigit(formatDate(info.dateOfBirth))
        let expiryPart = formatDate(info.dateOfExpiry) + calculateCheckDigit(formatDate(info.dateOfExpiry))
        let personalPart = formatPersonalNumber(info.personalNumber, maxLength: 14)
        let personalCheckPart = calculateCheckDigit(personalPart)
        
        let checkString = passportPart + birthPart + expiryPart + personalPart + personalCheckPart
        
        return calculateCheckDigit(checkString)
    }
}

// MARK: - 扩展方法

extension PassportMRZGenerator {
    
    /// 验证MRZ格式是否正确
    static func validateMRZ(_ mrz: MRZData) -> Bool {
        return mrz.line1.count == 44 && mrz.line2.count == 44
    }
    
    /// 从MRZ中提取BAC所需的信息
    /// - Parameter mrz: 完整的MRZ数据
    /// - Returns: BAC计算所需的信息 (护照号+校验位+出生日期+校验位+到期日期+校验位)
    static func extractBACString(from mrz: MRZData) -> String {
        // 从第二行提取BAC所需的部分
        let line2 = mrz.line2
        
        // 护照号(9) + 校验位(1) = 位置0-9
        let passportPart = String(line2.prefix(10))
        
        // 跳过国籍代码(3) = 位置10-12
        // 出生日期(6) + 校验位(1) = 位置13-19
        let birthPart = String(line2.dropFirst(13).prefix(7))
        
        // 跳过性别(1) = 位置20
        // 到期日期(6) + 校验位(1) = 位置21-27
        let expiryPart = String(line2.dropFirst(21).prefix(7))
        
        let bacString = passportPart + birthPart + expiryPart
        
        print("🔹 [MRZ Generator] BAC字符串提取:")
        print("🔹 [MRZ Generator] 护照部分: '\(passportPart)'")
        print("🔹 [MRZ Generator] 出生部分: '\(birthPart)'")
        print("🔹 [MRZ Generator] 到期部分: '\(expiryPart)'")
        print("🔹 [MRZ Generator] BAC字符串: '\(bacString)' (长度: \(bacString.count))")
        
        return bacString
    }
}
