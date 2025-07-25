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
            return "App Attest is not supported on this device"
        case .keyGenerationFailed:
            return "Key generation failed"
        case .attestationFailed:
            return "Device attestation failed"
        case .assertionFailed:
            return "Assertion generation failed"
        case .keyNotFound:
            return "Key not found"
        case .invalidChallenge:
            return "Invalid challenge data"
        case .serverError(let message):
            return "Server error: \(message)"
        case .certificateParsingFailed:
            return "Certificate parsing failed"
        case .certificateStorageFailed:
            return "Certificate storage failed"
        case .certificateNotFound:
            return "Certificate not found"
        }
    }
}