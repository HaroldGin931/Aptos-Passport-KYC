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
    @Sta            return "Face verification passed!"
        case .failed:
            return "Face verification failed, please try again."bject private var cameraManager = CameraManager()
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
            print("🖼️ [CompareWithCam] View appeared, starting camera setup")
            #endif
            setupCamera()
        }
        .onDisappear {
            #if DEBUG
            print("🖼️ [CompareWithCam] View disappeared, stopping camera")
            #endif
            cameraManager.stop()
        }
        .onReceive(cameraManager.$latestPixelBuffer.compactMap { $0 }) { pixelBuffer in
            #if DEBUG
            print("🖼️ [CompareWithCam] Received new pixel buffer, starting frame processing")
            #endif
            processFrame(pixelBuffer)
        }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            #if DEBUG
            print("🖼️ [CompareWithCam] shouldDismiss status changed: \(shouldDismiss)")
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
                Text("No face detected")
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
            // Control buttons
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
            return "Face verification passed!"
        case .failure:
            return "Face verification failed, please try again."
        case .none:
            return ""
        }
    }
    
    private func setupCamera() {
        #if DEBUG
        print("🖼️ [CompareWithCam] Starting camera setup")
        #endif
        cameraManager.start()
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        #if DEBUG
        print("🖼️ [CompareWithCam] Starting frame processing, current isComparing: \(viewModel.isComparing)")
        #endif
        
        // Avoid processing new frames during comparison
        guard !viewModel.isComparing else { 
            #if DEBUG
            print("🖼️ [CompareWithCam] Currently comparing, skipping current frame")
            #endif
            return 
        }
        
        // Extract face image from current frame
        guard let faceImage = cameraManager.extractFaceImage(from: pixelBuffer) else {
            #if DEBUG
            print("🖼️ [CompareWithCam] No face image extracted, calling noFaceDetected")
            #endif
            viewModel.noFaceDetected()
            return
        }
        
        #if DEBUG
        print("🖼️ [CompareWithCam] Successfully extracted face image, starting processing")
        #endif
        
        // Process face image
        viewModel.processFaceImage(faceImage)
    }
    
    private func resetComparison() {
        #if DEBUG
        print("🖼️ [CompareWithCam] Resetting comparison status")
        #endif
        viewModel.reset()
    }
    
    private func showFinalResult() {
        #if DEBUG
        print("🖼️ [CompareWithCam] Showing final result: \(viewModel.finalResult)")
        #endif
        // Stop camera
        cameraManager.stop()
        
        // Logic for automatically closing popup after showing result is already handled in alert
    }
}

// MARK: - Preview
#Preview {
    CompareWithCamView()
}
