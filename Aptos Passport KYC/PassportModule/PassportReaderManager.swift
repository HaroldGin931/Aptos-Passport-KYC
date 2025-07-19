//
//  PassportReaderManager.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import CoreNFC

// 兼容性类，为了不影响现有代码
class PassportReaderManager: ObservableObject {
    static let shared = PassportReaderManager()
    
    @Published var isReading = false
    
    private init() {}
    
    func isNFCAvailable() -> Bool {
        return NFCTagReaderSession.readingAvailable
    }
}
