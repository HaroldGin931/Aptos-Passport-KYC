//
//  ContentView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/16.
//

import SwiftUI

struct ContentView: View {
    @State private var isAttesting = false
    @State private var attestationMessage: String?
    @State private var showCompareSheet = false        // 控制 CompareWithCamView 弹窗
    @State private var selectedReferenceImage = "myface"  // 可选择的参考图片

    /// 点击按钮后触发 App Attest，结果写进 `attestationMessage`
    private func checkMyDevice() {
        isAttesting = true
        Task {
            do {
                // 调用你在其他文件里实现的 App Attest 入口
                // 下面示例假设函数为 `AttestationManager.shared.prepare() -> String`
                let keyID = try await AttestationManager.shared.prepare()
                attestationMessage = "✅ Verified. keyID: \(keyID.prefix(8))…"
            } catch {
                attestationMessage = "❌ \(error.localizedDescription)"
            }
            isAttesting = false
        }
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
            
            // Reference Image Selection
            referenceImageSection
            
            Button(action: checkMyDevice) {
                HStack {
                    Image(systemName: isAttesting ? "checkmark.circle" : "shield.checkered")
                    Text(isAttesting ? "Checking Device..." : "Check My Device")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAttesting)

            Button(action: compareFace) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Compare Face")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)

            if let msg = attestationMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showCompareSheet) {
            CompareWithCamView(referenceImageName: selectedReferenceImage)
        }
    }
    
    // MARK: - UI Components
    
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
}

#Preview {
    ContentView()
}
