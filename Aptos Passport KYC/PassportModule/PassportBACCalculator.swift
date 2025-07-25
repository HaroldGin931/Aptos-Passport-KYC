//
//  PassportBACCalculator.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import CryptoKit

/// Passport BAC (Basic Access Control) key calculation utility class
class PassportBACCalculator {
    
    // MARK: - BAC Key Calculation
    
    /// Generate MRZ key information (for BAC key calculation)
    /// - Parameters:
    ///   - passportNumber: Passport number
    ///   - dateOfBirth: Date of birth (YYMMDD format)
    ///   - dateOfExpiry: Date of expiry (YYMMDD format)
    /// - Returns: Formatted MRZ key string
    static func generateMRZKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> String {
        print("🔹 [BAC Calculator] Starting BAC key generation...")
        print("🔹 [BAC Calculator] Input parameters:")
        print("🔹 [BAC Calculator]   Passport number: '\(passportNumber)'")
        print("🔹 [BAC Calculator]   Date of birth: '\(dateOfBirth)'")
        print("🔹 [BAC Calculator]   Date of expiry: '\(dateOfExpiry)'")
        
        // Use new MRZ generator to generate complete MRZ
        let fullMRZ = PassportMRZGenerator.generateMRZ(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        print("🔹 [BAC Calculator] Complete MRZ generated:")
        print(fullMRZ.displayFormat)
        
        // Extract BAC string from complete MRZ
        let bacString = PassportMRZGenerator.extractBACString(from: fullMRZ)
        
        print("🔹 [BAC Calculator] BAC key: '\(bacString)' (length: \(bacString.count))")
        
        return bacString
    }
    
    /// Calculate BAC seed key (Kseed)
    /// - Parameters:
    ///   - passportNumber: Passport number
    ///   - dateOfBirth: Date of birth (YYMMDD format)
    ///   - dateOfExpiry: Date of expiry (YYMMDD format)
    /// - Returns: SHA-1 hashed seed key (first 16 bytes)
    static func calculateBACSeederKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> Data {
        let mrzKey = generateMRZKey(passportNumber: passportNumber, dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
        let mrzData = mrzKey.data(using: .utf8) ?? Data()
        
        print("🔹 [BAC Debug] MRZ key data (string): '\(mrzKey)'")
        print("🔹 [BAC Debug] MRZ key data (UTF-8 bytes): \(mrzData.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Use SHA-1 to calculate hash, then take first 16 bytes as seed key
        let sha1Hash = Data(Insecure.SHA1.hash(data: mrzData))
        let seedKey = Data(sha1Hash.prefix(16))
        
        print("🔹 [BAC Debug] Complete SHA-1 hash: \(sha1Hash.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("🔹 [BAC Debug] Seed key (first 16 bytes): \(seedKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        return seedKey
    }
    
    /// Derive BAC encryption and MAC keys using TR-SAC 1.01 standard
    /// - Parameters:
    ///   - passportNumber: Passport number
    ///   - dateOfBirth: Date of birth (YYMMDD format)
    ///   - dateOfExpiry: Date of expiry (YYMMDD format)
    /// - Returns: Tuple containing encryption and MAC keys
    static func deriveBACKeys(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> (encryptionKey: Data, macKey: Data) {
        let seedKey = calculateBACSeederKey(passportNumber: passportNumber, dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
        
        // Use TR-SAC 1.01 standard for key derivation
        let encryptionKey = deriveKey(from: seedKey, mode: .encryption)
        let macKey = deriveKey(from: seedKey, mode: .mac)
        
        return (encryptionKey, macKey)
    }
    
    /// Adjust key parity bits to comply with DES standard
    /// - Parameter key: Original key
    /// - Returns: Key with adjusted parity bits
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
    
    // MARK: - Key Derivation (according to TR-SAC 1.01 standard)
    
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
    
    /// Derive key according to TR-SAC 1.01 standard
    /// - Parameters:
    ///   - seedKey: 16-byte seed key
    ///   - mode: Derivation mode (encryption or MAC)
    /// - Returns: Derived key
    private static func deriveKey(from seedKey: Data, mode: KeyDerivationMode) -> Data {
        // Perform 3DES key derivation according to TR-SAC 1.01, 4.2.1
        let derivationData = seedKey + mode.constant
        
        print("🔹 [BAC Debug] Key derivation input (\(mode == .encryption ? "encryption" : "MAC")): \(derivationData.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        let hash = Data(Insecure.SHA1.hash(data: derivationData))
        
        print("🔹 [BAC Debug] Derivation hash: \(hash.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // For 3DES: take first 16 bytes, then add first 8 bytes to form 24-byte 3DES key
        let keyData = Data(hash.prefix(16))
        let expandedKey = keyData + Data(keyData.prefix(8))
        
        print("🔹 [BAC Debug] Final key (\(mode == .encryption ? "encryption" : "MAC")): \(expandedKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        return expandedKey
    }
    
    // MARK: - Formatting and Validation Helper Methods (retained for compatibility)
    
    /// Calculate check digit (according to ICAO 9303 standard)
    /// - Parameter input: Input string
    /// - Returns: Check digit character
    private static func calculateCheckDigit(_ input: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0
        
        print("🔹 [BAC Debug] Calculate check digit - input: '\(input)'")
        
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
            print("🔹 [BAC Debug]   Position \(index): '\(char)' -> value=\(value) × weight=\(weight) = \(value * weight), total=\(sum)")
        }
        
        let checkDigit = sum % 10
        print("🔹 [BAC Debug] Check digit calculation: sum=\(sum) % 10 = \(checkDigit)")
        
        return String(checkDigit)
    }
    
    // MARK: - Validation Methods
    
    /// Validate if BAC input information is valid
    /// - Parameters:
    ///   - passportNumber: Passport number
    ///   - dateOfBirth: Date of birth
    ///   - dateOfExpiry: Date of expiry
    /// - Returns: Validation result
    static func validateBACInputs(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> BACValidationResult {
        var errors: [String] = []
        
        // Validate passport number
        if passportNumber.isEmpty {
            errors.append("Passport number cannot be empty")
        } else if passportNumber.count > 9 {
            errors.append("Passport number cannot exceed 9 digits")
        }
        
        // Validate date of birth
        if dateOfBirth.count != 6 {
            errors.append("Date of birth must be 6 digits")
        } else if !dateOfBirth.allSatisfy({ $0.isNumber }) {
            errors.append("Date of birth can only contain numbers")
        }
        
        // Validate date of expiry
        if dateOfExpiry.count != 6 {
            errors.append("Date of expiry must be 6 digits")
        } else if !dateOfExpiry.allSatisfy({ $0.isNumber }) {
            errors.append("Date of expiry can only contain numbers")
        }
        
        // Validate date logic
        if errors.isEmpty {
            if !isValidDateFormat(dateOfBirth) {
                errors.append("Date of birth format is invalid")
            }
            if !isValidDateFormat(dateOfExpiry) {
                errors.append("Date of expiry format is invalid")
            }
        }
        
        return BACValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate if date format is valid
    /// - Parameter dateString: Date string in YYMMDD format
    /// - Returns: Whether it's valid
    private static func isValidDateFormat(_ dateString: String) -> Bool {
        guard dateString.count == 6,
              let month = Int(String(dateString.dropFirst(2).prefix(2))),
              let day = Int(String(dateString.suffix(2))) else {
            return false
        }
        
        return month >= 1 && month <= 12 && day >= 1 && day <= 31
    }
}

// MARK: - Data Structures

/// BAC validation result
struct BACValidationResult {
    let isValid: Bool
    let errors: [String]
}

/// BAC key information
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
    
    /// Get summary of BAC key information
    var summary: String {
        return """
        Passport Number: \(passportNumber)
        Date of Birth: \(dateOfBirth)
        Date of Expiry: \(dateOfExpiry)
        MRZ Key: \(mrzKey)
        Seed Key: \(seedKey.bacHexString)
        Encryption Key: \(encryptionKey.bacHexString)
        MAC Key: \(macKey.bacHexString)
        """
    }
}

// MARK: - Data Extension

extension Data {
    /// Convert Data to hexadecimal string
    var bacHexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
