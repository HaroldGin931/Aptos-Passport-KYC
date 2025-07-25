//
//  ContentView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/16.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var attestService = AppAttestService.shared
    @StateObject private var authStateManager = AuthenticationStateManager.shared
    @StateObject private var passportManager = PassportReaderManager.shared
    @State private var showCompareSheet = false
    @State private var selectedReferenceImage = "myface"
    @State private var showIntegrityView = false
    @State private var showPassportScanner = false

    /// Click button to open integrity verification interface
    private func openIntegrityView() {
        showIntegrityView = true
    }

    /// Passport scanning functionality
    private func scanPassport() {
        // Check device authentication status
        guard authStateManager.isAuthenticated else {
            print("❌ Passport scan failed: Device not authenticated")
            return
        }
        
        // Check NFC availability
        guard passportManager.isNFCAvailable() else {
            print("❌ This device does not support NFC functionality")
            return
        }
        
        print("📱 Starting passport scan...")
        print("✅ Device authenticated, allowing passport scan")
        showPassportScanner = true
    }

    /// Click button to open camera interface and compare faces in real time
    private func compareFace() {
        showCompareSheet = true
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Title
            Text("Aptos Passport KYC")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // App Attest Status
            attestStatusSection
            
            // Reference Image Selection
            referenceImageSection
            
            // Main Action Buttons
            actionButtonsSection
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showCompareSheet) {
            CompareWithCamView(referenceImageName: selectedReferenceImage)
        }
        .sheet(isPresented: $showIntegrityView) {
            IntegrityView()
        }
        .sheet(isPresented: $showPassportScanner) {
            ChinesePassportScannerView()
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var attestStatusSection: some View {
        HStack {
            Image(systemName: authStateManager.isAuthenticated ? "checkmark.shield.fill" : "xmark.shield.fill")
                .foregroundColor(authStateManager.isAuthenticated ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Status")
                    .font(.headline)
                
                if authStateManager.isAuthenticated {
                    Text("Authenticated")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let keyCheckDate = authStateManager.keyCheckDate {
                        Text("Check time: \(formatDate(keyCheckDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not Authenticated")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button("Manage Auth") {
                showIntegrityView = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: scanPassport) {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                    Text("Scan Passport")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!authStateManager.isAuthenticated) // Device authentication required first

            Button(action: compareFace) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Face Comparison")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!authStateManager.isAuthenticated) // Device authentication required first
        }
    }
    
    @ViewBuilder
    private var referenceImageSection: some View {
        VStack(spacing: 12) {
            Text("Reference Image")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                referenceImageButton(imageName: "myface", title: "Harold")
                referenceImageButton(imageName: "lucian", title: "Lucian")
            }
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private func referenceImageButton(imageName: String, title: String) -> some View {
        Button(action: {
            selectedReferenceImage = imageName
        }) {
            VStack(spacing: 8) {
                if let image = UIImage(named: imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(selectedReferenceImage == imageName ? Color.blue : Color.clear, lineWidth: 3)
                        )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(selectedReferenceImage == imageName ? .blue : .primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
