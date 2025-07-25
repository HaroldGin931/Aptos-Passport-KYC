//
//  FaceComparisonViewModel.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/17.
//

import SwiftUI
import Vision

// MARK: - Enums
enum ComparisonResult {
    case waiting
    case match
    case noMatch
    
    var color: Color {
        switch self {
        case .waiting: return .blue
        case .match: return .green
        case .noMatch: return .red
        }
    }
}

enum FinalResult {
    case none
    case success
    case failure
    
    var color: Color {
        switch self {
        case .none: return .primary
        case .success: return .green
        case .failure: return .red
        }
    }
}

// MARK: - Face Comparison View Model
@MainActor
final class FaceComparisonViewModel: ObservableObject {
    
    @Published var distance: Float = .greatestFiniteMagnitude
    @Published var comparisonResult: ComparisonResult = .waiting
    @Published var statusMessage = "Please align your face with the camera"
    @Published var shouldDismiss = false
    @Published var finalResult: FinalResult = .none
    
    // Processing status flag
    @Published private var isProcessing = false
    
    var isComparing: Bool {
        get { isProcessingInternal }
        set { 
            #if DEBUG
            if newValue != isProcessingInternal {
                print("🔄 [isComparing] Status changed: \(isProcessingInternal) -> \(newValue)")
            }
            #endif
            isProcessingInternal = newValue 
        }
    }
    
    // Internal state
    private var isProcessingInternal = false
    private var successCounter = 0
    private var totalDetections = 0
    
    // Image processing
    private var _referenceImage: UIImage?
    private var referenceFeaturePrint: VNFeaturePrintObservation?
    
    // Public accessor
    var referenceImage: UIImage? {
        return _referenceImage
    }
    
    // Constants
    private let maxDetections = 100
    private let successThreshold = 20
    private let similarityThreshold: Float = 0.69
    
    init(referenceImage: UIImage, algorithmName: String? = nil) {
        self._referenceImage = referenceImage
        #if DEBUG
        print("🚀 [FaceComparisonViewModel] Initializing")
        #endif
        loadReferenceImage()
    }
    
    // MARK: - Image Loading
    
    private func loadReferenceImage() {
        #if DEBUG
        print("📸 [loadReferenceImage] Starting to load reference image")
        #endif
        
        guard let image = _referenceImage else {
            #if DEBUG
            print("❌ [loadReferenceImage] Unable to load reference image")
            #endif
            return
        }
        
        // Asynchronously extract reference image features
        Task {
            await extractReferenceFeatures()
        }
    }
    
    private func extractReferenceFeatures() async {
        guard let image = _referenceImage else { return }
        
        do {
            referenceFeaturePrint = try await extractFeaturePrint(from: image)
            #if DEBUG
            print("✅ [extractReferenceFeatures] Reference image feature extraction successful")
            #endif
        } catch {
            #if DEBUG
            print("❌ [extractReferenceFeatures] Reference image feature extraction failed: \(error)")
            #endif
        }
    }
    
    // MARK: - Face Detection and Processing
    
    /// Process camera image
    func processFaceImage(_ image: UIImage) {
        // Prevent duplicate processing
        guard !isProcessingInternal else { return }
        
        #if DEBUG
        print("🔄 [processFaceImage] Starting image processing")
        #endif
        
        Task {
            await processImage(image)
        }
    }
    
    private func processImage(_ image: UIImage) async {
        isProcessingInternal = true
        
        defer {
            isProcessingInternal = false
        }
        
        do {
            guard let currentFeaturePrint = try await extractFeaturePrint(from: image) else {
                noFaceDetected()
                return
            }
            
            await compareFeatures(currentFeaturePrint)
            
        } catch {
            #if DEBUG
            print("❌ [processImage] Processing failed: \(error)")
            #endif
            noFaceDetected()
        }
    }
    
    /// Feature extraction
    private func extractFeaturePrint(from image: UIImage) async throws -> VNFeaturePrintObservation? {
        return try await withCheckedThrowingContinuation { continuation in
            guard let ciImage = CIImage(image: image) else {
                continuation.resume(throwing: NSError(domain: "ImageProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create CIImage"]))
                return
            }
            
            // First perform face detection
            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Process detected faces
                let faces = request.results as? [VNFaceObservation] ?? []
                
                var processedImage = ciImage
                
                // If face is detected, crop face region
                if let face = faces.first {
                    let boundingBox = face.boundingBox
                    let imageSize = ciImage.extent.size
                    
                    // Convert Vision coordinate system to image coordinate system
                    let faceRect = CGRect(
                        x: boundingBox.origin.x * imageSize.width,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
                        width: boundingBox.width * imageSize.width,
                        height: boundingBox.height * imageSize.height
                    )
                    
                    // Expand face region boundaries to include more context
                    let expandedRect = faceRect.insetBy(dx: -faceRect.width * 0.2, dy: -faceRect.height * 0.2)
                    let clampedRect = expandedRect.intersection(ciImage.extent)
                    
                    if !clampedRect.isEmpty && clampedRect.width > 50 && clampedRect.height > 50 {
                        processedImage = ciImage.cropped(to: clampedRect)
                        
                        #if DEBUG
                        print("✅ [extractFeaturePrint] Successfully cropped face region: \(clampedRect)")
                        #endif
                    }
                }
                
                // Use processed image for feature extraction
                let featurePrintRequest = VNGenerateImageFeaturePrintRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNFeaturePrintObservation],
                          let featurePrint = observations.first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    continuation.resume(returning: featurePrint)
                }
                
                let handler = VNImageRequestHandler(ciImage: processedImage, options: [:])
                
                do {
                    try handler.perform([featurePrintRequest])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            
            do {
                try handler.perform([faceRequest])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Compare features
    private func compareFeatures(_ currentFeaturePrint: VNFeaturePrintObservation) async {
        guard let referenceFeaturePrint = referenceFeaturePrint else {
            #if DEBUG
            print("⚠️ [compareFeatures] Reference features do not exist")
            #endif
            noFaceDetected()
            return
        }
        
        do {
            var distanceValue: Float = 0
            try referenceFeaturePrint.computeDistance(&distanceValue, to: currentFeaturePrint)
            
            #if DEBUG
            print("📊 [compareFeatures] Calculated distance: \(distanceValue)")
            #endif
            
            totalDetections += 1
            distance = distanceValue
            
            if distanceValue <= similarityThreshold {
                successCounter += 1
                comparisonResult = .match
                statusMessage = String(format: "Match successful! Distance: %.4f (Success: %d/%d)", distanceValue, successCounter, totalDetections)
                
                #if DEBUG
                print("✅ [compareFeatures] Match successful! Distance: \(distanceValue)")
                #endif
            } else {
                // If distance exceeds 1, decrease successCounter
                if distanceValue > 1.0 {
                    successCounter -= 1
                }
                comparisonResult = .noMatch
                statusMessage = String(format: "No match. Distance: %.4f (Success: %d/%d)", distanceValue, successCounter, totalDetections)
                
                #if DEBUG
                print("❌ [compareFeatures] No match. Distance: \(distanceValue)")
                #endif
            }
            
            checkEndConditions()
            
        } catch {
            #if DEBUG
            print("❌ [compareFeatures] Distance calculation failed: \(error)")
            #endif
            noFaceDetected()
        }
    }
    
    /// Called when no face is detected
    func noFaceDetected() {
        guard !isProcessingInternal else { return }
        
        #if DEBUG
        print("👤 [noFaceDetected] No face detected")
        #endif
        
        totalDetections += 1
        
        distance = .greatestFiniteMagnitude
        comparisonResult = .waiting
        statusMessage = String(format: "No face detected (Count: %d/%d)", successCounter, totalDetections)
        
        // Check if maximum detection limit is reached
        checkEndConditions()
    }
    
    /// Check end conditions
    private func checkEndConditions() {
        #if DEBUG
        print("🔍 [checkEndConditions] Checking end conditions - Success: \(successCounter)/\(successThreshold), Total: \(totalDetections)/\(maxDetections)")
        #endif
        
        // If successCounter reaches 20, immediately succeed
        if successCounter >= successThreshold {
            finalResult = .success
            statusMessage = String(format: "Verification successful! Match count: %d/%d", successCounter, totalDetections)
            
            #if DEBUG
            print("🎉 [checkEndConditions] Immediate verification success!")
            #endif
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.shouldDismiss = true
            }
        } else if totalDetections >= maxDetections {
            // When all detections are complete, consider success if successCounter > 10
            if successCounter > 10 {
                finalResult = .success
                statusMessage = String(format: "Verification successful! Match count: %d/%d", successCounter, totalDetections)
                
                #if DEBUG
                print("🎉 [checkEndConditions] Verification successful after detection completion!")
                #endif
            } else {
                finalResult = .failure
                statusMessage = String(format: "Verification failed. Match count: %d/%d", successCounter, totalDetections)
                
                #if DEBUG
                print("💔 [checkEndConditions] Verification failed")
                #endif
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.shouldDismiss = true
            }
        }
    }
    
    /// Reset state
    func reset() {
        #if DEBUG
        print("🔄 [reset] Reset state")
        #endif
        
        isProcessingInternal = false
        successCounter = 0
        totalDetections = 0
        distance = .greatestFiniteMagnitude
        comparisonResult = .waiting
        statusMessage = "Please align your face with the camera"
        shouldDismiss = false
        finalResult = .none
    }
}
