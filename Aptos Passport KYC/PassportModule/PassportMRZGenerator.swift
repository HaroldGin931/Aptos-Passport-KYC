//
//  PassportMRZGenerator.swift
//         let nationality: String         // Nationality code (3 characters, e.g. "CHN")
        let dateOfBirth: String        // Date of birth (YYMMDD)
        let gender: String             // Gender ("M"/"F"/"<")
        let dateOfExpiry: String       // Date of expiry (YYMMDD)
        let personalNumber: String?    // Personal number (optional)
    }
    
    // MARK: - Public Methods
    
    /// Generate complete passport MRZ
    /// - Parameter info: Passport information
    /// - Returns: Complete MRZ dataort KYC
//
//  Created by Harold on 2025/7/19.
//

import Foundation

/// Passport MRZ (Machine Readable Zone) generator
/// Generates complete passport MRZ according to ICAO 9303 standard
class PassportMRZGenerator {
    
    // MARK: - MRZ Data Structures
    
    struct MRZData {
        let line1: String  // First line (44 characters)
        let line2: String  // Second line (44 characters)
        
        var fullMRZ: String {
            return line1 + line2
        }
        
        var displayFormat: String {
            return """
            Line 1: \(line1)
            Line 2: \(line2)
            """
        }
    }
    
    struct PassportInfo {
        let documentType: String        // Document type (usually "P")
        let issuingCountry: String      // Issuing country code (3 characters, e.g. "CHN")
        let lastName: String            // Last name
        let firstName: String           // First name
        let passportNumber: String      // Passport number
        let nationality: String         // Nationality code (3 characters, e.g. "CHN")
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
        
        print("🔹 [MRZ Generator] Generating complete MRZ:")
        print("🔹 [MRZ Generator] Line 1: '\(line1)'")
        print("🔹 [MRZ Generator] Line 2: '\(line2)'")
        print("🔹 [MRZ Generator] Line 1 length: \(line1.count)")
        print("🔹 [MRZ Generator] Line 2 length: \(line2.count)")
        
        return MRZData(line1: line1, line2: line2)
    }
    
    /// Generate MRZ from basic passport information (simplified version)
    /// - Parameters:
    ///   - passportNumber: Passport number
    ///   - dateOfBirth: Date of birth (YYMMDD)
    ///   - dateOfExpiry: Date of expiry (YYMMDD)
    ///   - lastName: Last name (optional, defaults to "UNKNOWN")
    ///   - firstName: First name (optional, defaults to "UNKNOWN")
    /// - Returns: Complete MRZ data
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
    
    // MARK: - Private Methods
    
    /// Generate MRZ first line
    /// Format: P<ISSCOUNTRY<LASTNAME<<FIRSTNAME<<<<<<<<<<<<<<<<<<<<<<
    /// Length: 44 characters
    private static func generateLine1(info: PassportInfo) -> String {
        var line1 = ""
        
        // 1. Document type (1 character)
        line1 += info.documentType
        
        // 2. Country code identifier "<" (1 character)
        line1 += "<"
        
        // 3. Issuing country code (3 characters)
        line1 += formatCountryCode(info.issuingCountry)
        
        // 4. Name field (39 characters)
        let nameField = formatNameField(lastName: info.lastName, firstName: info.firstName, maxLength: 39)
        line1 += nameField
        
        // Ensure length is 44 characters
        line1 = padToLength(line1, length: 44)
        
        return line1
    }
    
    /// Generate MRZ second line
    /// Format: PASSPORTNUMBER<NATIONALITY<YYMMDD<GENDER<YYMMDD<PERSONALNUMBER<<CHECKDIGIT
    /// Length: 44 characters
    private static func generateLine2(info: PassportInfo) -> String {
        var line2 = ""
        
        // 1. Passport number (9 characters) + check digit (1 character)
        let formattedPassportNumber = formatPassportNumber(info.passportNumber)
        let passportCheckDigit = calculateCheckDigit(formattedPassportNumber)
        line2 += formattedPassportNumber + passportCheckDigit
        
        // 2. Nationality code (3 characters)
        line2 += formatCountryCode(info.nationality)
        
        // 3. Date of birth (6 characters) + check digit (1 character)
        let formattedBirthDate = formatDate(info.dateOfBirth)
        let birthCheckDigit = calculateCheckDigit(formattedBirthDate)
        line2 += formattedBirthDate + birthCheckDigit
        
        // 4. Gender (1 character)
        line2 += formatGender(info.gender)
        
        // 5. Date of expiry (6 characters) + check digit (1 character)
        let formattedExpiryDate = formatDate(info.dateOfExpiry)
        let expiryCheckDigit = calculateCheckDigit(formattedExpiryDate)
        line2 += formattedExpiryDate + expiryCheckDigit
        
        // 6. Personal number field (14 characters)
        let personalNumberField = formatPersonalNumber(info.personalNumber, maxLength: 14)
        line2 += personalNumberField
        
        // 7. Personal number check digit (1 character)
        let personalNumberCheckDigit = calculateCheckDigit(personalNumberField)
        line2 += personalNumberCheckDigit
        
        // 8. Overall check digit (1 character) - checksum for specific parts of the entire second line
        let overallCheckDigit = calculateOverallCheckDigit(line2: line2, info: info)
        line2 += overallCheckDigit
        
        // Ensure length is 44 characters
        line2 = padToLength(line2, length: 44)
        
        return line2
    }
    
    // MARK: - Formatting Helper Methods
    
    /// Format passport number
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
    
    /// Format country code
    private static func formatCountryCode(_ countryCode: String) -> String {
        let cleanCode = countryCode.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanCode.count >= 3 {
            return String(cleanCode.prefix(3))
        } else {
            return cleanCode + String(repeating: "<", count: 3 - cleanCode.count)
        }
    }
    
    /// Format name field
    private static func formatNameField(lastName: String, firstName: String, maxLength: Int) -> String {
        let cleanLastName = lastName.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "<")
        
        let cleanFirstName = firstName.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "<")
        
        // Format: LASTNAME<<FIRSTNAME
        var nameField = cleanLastName + "<<" + cleanFirstName
        
        // If exceeds maximum length, truncate
        if nameField.count > maxLength {
            nameField = String(nameField.prefix(maxLength))
        } else {
            // Pad with < to specified length
            nameField += String(repeating: "<", count: maxLength - nameField.count)
        }
        
        return nameField
    }
    
    /// Format date
    private static func formatDate(_ date: String) -> String {
        let cleanDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanDate.count == 6 && cleanDate.allSatisfy({ $0.isNumber }) {
            return cleanDate
        } else {
            return "000000"
        }
    }
    
    /// Format gender
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
    
    /// Format personal number field
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
    
    /// Pad to specified length
    private static func padToLength(_ string: String, length: Int) -> String {
        if string.count >= length {
            return String(string.prefix(length))
        } else {
            return string + String(repeating: "<", count: length - string.count)
        }
    }
    
    // MARK: - Check Digit Calculation
    
    /// Calculate check digit (according to ICAO 9303 standard)
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
                // Convert letters to numbers (A=10, B=11, ..., Z=35)
                let ascii = char.asciiValue ?? 0
                if ascii >= 65 && ascii <= 90 { // A-Z
                    value = Int(ascii - 55)
                }
            }
            
            sum += value * weight
        }
        
        return String(sum % 10)
    }
    
    /// Calculate overall check digit
    /// Checksum for passport number+check digit+birth date+check digit+expiry date+check digit+personal number+check digit
    private static func calculateOverallCheckDigit(line2: String, info: PassportInfo) -> String {
        // Build string for overall checksum
        let passportPart = formatPassportNumber(info.passportNumber) + calculateCheckDigit(formatPassportNumber(info.passportNumber))
        let birthPart = formatDate(info.dateOfBirth) + calculateCheckDigit(formatDate(info.dateOfBirth))
        let expiryPart = formatDate(info.dateOfExpiry) + calculateCheckDigit(formatDate(info.dateOfExpiry))
        let personalPart = formatPersonalNumber(info.personalNumber, maxLength: 14)
        let personalCheckPart = calculateCheckDigit(personalPart)
        
        let checkString = passportPart + birthPart + expiryPart + personalPart + personalCheckPart
        
        return calculateCheckDigit(checkString)
    }
}

// MARK: - Extension Methods

extension PassportMRZGenerator {
    
    /// Validate if MRZ format is correct
    static func validateMRZ(_ mrz: MRZData) -> Bool {
        return mrz.line1.count == 44 && mrz.line2.count == 44
    }
    
    /// Extract BAC required information from MRZ
    /// - Parameter mrz: Complete MRZ data
    /// - Returns: Information required for BAC calculation (passport number+check digit+birth date+check digit+expiry date+check digit)
    static func extractBACString(from mrz: MRZData) -> String {
        // Extract BAC required parts from second line
        let line2 = mrz.line2
        
        // Passport number(9) + check digit(1) = positions 0-9
        let passportPart = String(line2.prefix(10))
        
        // Skip nationality code(3) = positions 10-12
        // Birth date(6) + check digit(1) = positions 13-19
        let birthPart = String(line2.dropFirst(13).prefix(7))
        
        // Skip gender(1) = position 20
        // Expiry date(6) + check digit(1) = positions 21-27
        let expiryPart = String(line2.dropFirst(21).prefix(7))
        
        let bacString = passportPart + birthPart + expiryPart
        
        print("🔹 [MRZ Generator] BAC string extraction:")
        print("🔹 [MRZ Generator] Passport part: '\(passportPart)'")
        print("🔹 [MRZ Generator] Birth part: '\(birthPart)'")
        print("🔹 [MRZ Generator] Expiry part: '\(expiryPart)'")
        print("🔹 [MRZ Generator] BAC string: '\(bacString)' (length: \(bacString.count))")
        
        return bacString
    }
}
