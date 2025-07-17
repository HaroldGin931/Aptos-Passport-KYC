//
//  CompareWithCam.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/17.
//

import SwiftUI

// MARK: - Face Comparison View
struct CompareWithCamView: View {
    
    // Dependencies
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel: FaceComparisonViewModel
    
    // UI State
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(referenceImageName: String = "myface", algorithmName: String? = nil) {
        guard let referenceImage = UIImage(named: referenceImageName) else {
            fatalError("Reference image '\(referenceImageName)' not found in bundle")
        }
        self._viewModel = StateObject(wrappedValue: FaceComparisonViewModel(referenceImage: referenceImage, algorithmName: algorithmName))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Reference Image Section
                referenceImageSection
                
                // Camera Preview Section
                cameraPreviewSection
                
                // Status Section
                statusSection
                
                // Controls Section
                controlsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Face Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            print("🖼️ [CompareWithCam] 视图出现，开始设置摄像头")
            #endif
            setupCamera()
        }
        .onDisappear {
            #if DEBUG
            print("🖼️ [CompareWithCam] 视图消失，停止摄像头")
            #endif
            cameraManager.stop()
        }
        .onReceive(cameraManager.$latestPixelBuffer.compactMap { $0 }) { pixelBuffer in
            #if DEBUG
            print("🖼️ [CompareWithCam] 接收到新的像素缓冲区，开始处理帧")
            #endif
            processFrame(pixelBuffer)
        }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            #if DEBUG
            print("🖼️ [CompareWithCam] shouldDismiss状态改变: \(shouldDismiss)")
            #endif
            if shouldDismiss {
                showFinalResult()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Face Comparison Result", isPresented: .constant(viewModel.shouldDismiss)) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(finalResultMessage)
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var referenceImageSection: some View {
        VStack(spacing: 8) {
            Text("Reference Image")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let referenceImage = viewModel.referenceImage {
                Image(uiImage: referenceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(12)
                    .shadow(radius: 2)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .cornerRadius(12)
                    .overlay(
                        Text("No Reference Image")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var cameraPreviewSection: some View {
        VStack(spacing: 8) {
            Text("Camera Preview")
                .font(.headline)
                .foregroundColor(.secondary)
            
            CameraPreviewView(session: cameraManager.session)
                .frame(height: 320)
                .cornerRadius(12)
                .shadow(radius: 2)
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 8) {
            if viewModel.comparisonResult == .waiting {
                Text("未检测到人脸")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            } else {
                Text(String(format: "Difference: %.2f", viewModel.distance))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .frame(minHeight: 60)
    }
    
    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // 控制按钮
            HStack(spacing: 16) {
                Button(action: resetComparison) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { cameraManager.isRunning ? cameraManager.stop() : cameraManager.start() }) {
                    Label(
                        cameraManager.isRunning ? "Stop Camera" : "Start Camera",
                        systemImage: cameraManager.isRunning ? "camera.fill" : "camera"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var borderColor: Color {
        switch viewModel.comparisonResult {
        case .waiting:
            return .blue
        case .match:
            return .green
        case .noMatch:
            return .red
        }
    }
    
    private var statusColor: Color {
        switch viewModel.comparisonResult {
        case .waiting:
            return .primary
        case .match:
            return .green
        case .noMatch:
            return .red
        }
    }
    
    // MARK: - Private Methods
    
    private var finalResultMessage: String {
        switch viewModel.finalResult {
        case .success:
            return "人脸验证通过！"
        case .failure:
            return "人脸验证失败，请重试。"
        case .none:
            return ""
        }
    }
    
    private func setupCamera() {
        #if DEBUG
        print("🖼️ [CompareWithCam] 开始设置摄像头")
        #endif
        cameraManager.start()
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        #if DEBUG
        print("🖼️ [CompareWithCam] 开始处理帧，当前isComparing: \(viewModel.isComparing)")
        #endif
        
        // 避免在比较过程中处理新帧
        guard !viewModel.isComparing else { 
            #if DEBUG
            print("🖼️ [CompareWithCam] 正在比较中，跳过当前帧")
            #endif
            return 
        }
        
        // 从当前帧提取人脸图像
        guard let faceImage = cameraManager.extractFaceImage(from: pixelBuffer) else {
            #if DEBUG
            print("🖼️ [CompareWithCam] 未提取到人脸图像，调用noFaceDetected")
            #endif
            viewModel.noFaceDetected()
            return
        }
        
        #if DEBUG
        print("🖼️ [CompareWithCam] 成功提取人脸图像，开始处理")
        #endif
        
        // 处理人脸图像
        viewModel.processFaceImage(faceImage)
    }
    
    private func resetComparison() {
        #if DEBUG
        print("🖼️ [CompareWithCam] 重置比较状态")
        #endif
        viewModel.reset()
    }
    
    private func showFinalResult() {
        #if DEBUG
        print("🖼️ [CompareWithCam] 显示最终结果: \(viewModel.finalResult)")
        #endif
        // 停止摄像头
        cameraManager.stop()
        
        // 显示结果后自动关闭弹窗的逻辑已经在 alert 中处理
    }
}

// MARK: - Preview
#Preview {
    CompareWithCamView()
}
