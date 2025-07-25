//
//  ChinesePassportScannerView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import SwiftUI

struct ChinesePassportScannerView: View {
    @StateObject private var passportReader = ChinesePassportReader()
    @Environment(\.dismiss) private var dismiss
    
    // MRZ information input
    @State private var passportNumber = "E00000000"
    @State private var dateOfBirth = "900101"
    @State private var dateOfExpiry = "251231"
    
    // BAC calculation related
    @State private var bacKeyInfo: BACKeyInfo?
    @State private var bacValidationResult: BACValidationResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Always show input interface
                mrzInputView
                
                // BAC authentication success status display
                if passportReader.bacAuthenticated {
                    bacSuccessView
                }
                
                // Passport information display
                if let passport = passportReader.passportData {
                    passportInfoSection(passport)
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Passport Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        passportReader.stopReading()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(passportReader.errorMessage != nil)) {
                Button("OK") {
                    passportReader.errorMessage = nil
                }
            } message: {
                if let errorMessage = passportReader.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - MRZ Information Input Interface
    private var mrzInputView: some View {
        VStack(spacing: 25) {
            // Title
            VStack(spacing: 10) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Passport Information Input")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Please enter basic passport information for BAC key calculation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Input form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passport Number")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("e.g.: EA1234567", text: $passportNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth (YYMMDD)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("e.g.: 900115", text: $dateOfBirth)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: dateOfBirth) { oldValue, newValue in
                            if newValue.count > 6 {
                                dateOfBirth = String(newValue.prefix(6))
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expiry Date (YYMMDD)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("e.g.: 300115", text: $dateOfExpiry)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: dateOfExpiry) { oldValue, newValue in
                            if newValue.count > 6 {
                                dateOfExpiry = String(newValue.prefix(6))
                            }
                        }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Information Guide:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("• Passport Number: 9-digit alphanumeric combination on passport cover")
                Text("• Date of Birth: YYMMDD format, e.g., January 15, 1990 = 900115")
                Text("• Expiry Date: YYMMDD format, e.g., January 15, 2030 = 300115")
                Text("• This information is used to calculate BAC keys, ensuring secure passport reading")
                
                // Display validation errors (if any)
                if let validationResult = bacValidationResult, !validationResult.isValid {
                    Divider()
                    Text("⚠️ Input validation errors:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    ForEach(validationResult.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                // First validate and calculate BAC information
                updateBACInfo()
                if bacValidationResult?.isValid == true {
                    // Reset status
                    passportReader.bacAuthenticated = false
                    passportReader.passportData = nil
                    passportReader.errorMessage = nil
                    
                    // Directly start NFC scanning without switching pages
                    let mrzInfo = MRZInfo(
                        documentNumber: passportNumber,
                        dateOfBirth: dateOfBirth,
                        dateOfExpiry: dateOfExpiry,
                        checkDigits: "" // Can be empty here, mainly for display
                    )
                    
                    passportReader.readPassport(with: mrzInfo)
                }
            }) {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("Start NFC Scan")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidMRZInput() ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .disabled(!isValidMRZInput())
        }
    }
    
    // MARK: - BAC Authentication Success View
    private var bacSuccessView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("BAC Check Passed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            Text("Reading passport data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green, lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    private func isValidMRZInput() -> Bool {
        let validation = PassportBACCalculator.validateBACInputs(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        return validation.isValid
    }
    
    /// Update BAC key information
    private func updateBACInfo() {
        // Validate input
        bacValidationResult = PassportBACCalculator.validateBACInputs(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        // If validation passes, calculate BAC keys
        if bacValidationResult?.isValid == true {
            bacKeyInfo = BACKeyInfo(
                passportNumber: passportNumber,
                dateOfBirth: dateOfBirth,
                dateOfExpiry: dateOfExpiry
            )
        } else {
            bacKeyInfo = nil
        }
    }
    
    /// Get BAC key summary information (for debugging)
    private func getBACKeySummary() -> String {
        return bacKeyInfo?.summary ?? "BAC keys not calculated"
    }
    
    /// Mask sensitive information for display
    private func maskSensitiveInfo(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        if text.count <= 2 {
            return String(repeating: "●", count: text.count)
        } else if text.count <= 4 {
            // Show first 1 and last 1 characters, dots in between
            return String(text.prefix(1)) + String(repeating: "●", count: text.count - 2) + String(text.suffix(1))
        } else {
            // Show first 2 and last 2 characters, dots in between
            return String(text.prefix(2)) + String(repeating: "●", count: text.count - 4) + String(text.suffix(2))
        }
    }
    
    // MARK: - Passport Information Display
    private func passportInfoSection(_ passport: ChinesePassportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Read Successfully")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Group {
                InfoRow(title: "Name", value: "\(passport.lastName) \(passport.firstName)")
                InfoRow(title: "Passport Number", value: maskSensitiveInfo(passport.documentNumber))
                InfoRow(title: "Nationality", value: passport.nationality)
                InfoRow(title: "Issuing Country", value: passport.issuingAuthority)
                InfoRow(title: "Gender", value: passport.gender)
                
                if let birthDate = passport.dateOfBirth {
                    InfoRow(title: "Date of Birth", value: formatDate(birthDate))
                }
                
                if let expiryDate = passport.dateOfExpiry {
                    InfoRow(title: "Expiry Date", value: formatDate(expiryDate))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green, lineWidth: 2)
        )
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// MARK: - Information Row Component
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}
