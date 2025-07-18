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
    @State private var showCompareSheet = false
    @State private var selectedReferenceImage = "myface"
    @State private var showIntegrityView = false

    /// 点击按钮后打开完整性验证界面
    private func openIntegrityView() {
        showIntegrityView = true
    }

    /// 扫描护照功能 (预留)
    private func scanPassport() {
        // 检查设备认证状态
        guard authStateManager.isAuthenticated else {
            print("❌ 扫描护照失败: 设备未认证")
            return
        }
        
        // 预留给护照扫描功能
        print("📱 开始扫描护照...")
        print("✅ 设备已认证，允许扫描护照")
        print("🔧 护照扫描功能待实现")
    }

    /// 点击按钮后弹出摄像头界面并实时对比人脸
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
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var attestStatusSection: some View {
        HStack {
            Image(systemName: authStateManager.isAuthenticated ? "checkmark.shield.fill" : "xmark.shield.fill")
                .foregroundColor(authStateManager.isAuthenticated ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("设备状态")
                    .font(.headline)
                
                if authStateManager.isAuthenticated {
                    Text("已认证")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let keyCheckDate = authStateManager.keyCheckDate {
                        Text("检查时间: \(formatDate(keyCheckDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("未认证")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button("管理认证") {
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
                    Text("扫描护照")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!authStateManager.isAuthenticated) // 需要先认证设备

            Button(action: compareFace) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("人脸对比")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!authStateManager.isAuthenticated) // 需要先认证设备
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
