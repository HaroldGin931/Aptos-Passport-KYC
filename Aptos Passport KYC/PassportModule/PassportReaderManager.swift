//
//  PassportReaderManager.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import CoreNFC

// Compatibility class to avoid affecting existing code
class PassportReaderManager: ObservableObject {
    static let shared = PassportReaderManager()
    
    @Published var isReading = false
    
    private init() {}
    
    func isNFCAvailable() -> Bool {
        return NFCTagReaderSession.readingAvailable
    }
}
