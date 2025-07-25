//
//  CameraManager.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/17.
//

import UIKit
import AVFoundation
import Vision
import CoreImage

// MARK: - CameraManager —— Responsible for capturing pixel buffers and publishing
final class CameraManager: NSObject, ObservableObject {
    
    @Published var latestPixelBuffer: CVPixelBuffer?     // Latest video frame
    @Published var session = AVCaptureSession()          // Publicly published session
    @Published var isRunning = false                     // Camera running status
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "cam.queue", qos: .userInitiated)
    
    override init() {
        super.init()
        setupCamera()
    }
    
    /// Set up camera configuration
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            Swift.print("❌ front camera unavailable")
            session.commitConfiguration()
            return
        }
        
        session.addInput(input)
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        
        session.addOutput(videoOutput)
        videoOutput.connections.first?.videoOrientation = .portrait
        
        session.commitConfiguration()
    }
    
    /// Start camera
    func start() {
        guard !isRunning else { 
            #if DEBUG
            Swift.print("📹 [CameraManager] Camera already running, skipping start")
            #endif
            return 
        }
        
        #if DEBUG
        Swift.print("📹 [CameraManager] Starting camera")
        #endif
        
        sessionQueue.async {
            #if DEBUG
            Swift.print("📹 [CameraManager] Starting camera in session queue")
            #endif
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
                #if DEBUG
                Swift.print("📹 [CameraManager] Camera startup completed, status updated")
                #endif
            }
        }
    }
    
    /// Stop camera
    func stop() {
        guard isRunning else { 
            #if DEBUG
            Swift.print("📹 [CameraManager] Camera already stopped, skipping stop operation")
            #endif
            return 
        }
        
        #if DEBUG
        Swift.print("📹 [CameraManager] Starting to stop camera")
        #endif
        
        sessionQueue.async {
            #if DEBUG
            Swift.print("📹 [CameraManager] Stopping camera in session queue")
            #endif
            
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isRunning = false
                #if DEBUG
                Swift.print("📹 [CameraManager] Camera stop completed, status updated")
                #endif
            }
        }
    }
    
    /// Extract face image from current frame
    func extractFaceImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        #if DEBUG
        Swift.print("🔍 [CameraManager] Starting to extract face image from pixel buffer")
        #endif
        
        var detector = FaceDetector()
        let detection = detector.detect(in: pixelBuffer)
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] Face detection result: count=\(detection.count), first box=\(detection.firstBox?.debugDescription ?? "none")")
        #endif
        
        guard let box = detection.firstBox else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] No face detected, returning nil")
            #endif
            return nil
        }
        
        // Calculate pixel ROI (flip Y axis)
        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let rect = CGRect(x: box.origin.x * w,
                          y: (1 - box.origin.y - box.height) * h,
                          width: box.width * w,
                          height: box.height * h)
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] Pixel buffer size: \(w)x\(h), face box: \(rect)")
        #endif
        
        // Validate boundary values
        guard rect.width > 0 && rect.height > 0 && 
              rect.origin.x >= 0 && rect.origin.y >= 0 && 
              rect.maxX <= w && rect.maxY <= h else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] Face box boundaries invalid, returning nil")
            #endif
            return nil
        }
        
        // Crop ROI from pixelBuffer -> UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).cropped(to: rect)
        let context = CIContext()
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] Created CI image, extent: \(ciImage.extent)")
        #endif
        
        // Ensure CIImage extent is valid
        guard !ciImage.extent.isEmpty else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] CI image extent is empty, returning nil")
            #endif
            return nil
        }
        
        guard let cgFace = context.createCGImage(ciImage, from: ciImage.extent) else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] Failed to create CG image, returning nil")
            #endif
            return nil
        }
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] Successfully extracted face image, size: \(cgFace.width)x\(cgFace.height)")
        #endif
        
        return UIImage(cgImage: cgFace)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        #if DEBUG
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        Swift.print("📹 [CameraManager] Received new video frame, timestamp: \(timestamp.seconds)")
        #endif
        
        DispatchQueue.main.async {
            self.latestPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            #if DEBUG
            Swift.print("📹 [CameraManager] Video frame updated on main thread")
            #endif
        }
    }
}

// MARK: - FaceDetector —— Only responsible for returning face box count and first box
struct FaceDetector {
    
    private let request = VNDetectFaceRectanglesRequest()
    
    mutating func detect(in pixelBuffer: CVPixelBuffer) -> (count: Int, firstBox: CGRect?) {
        #if DEBUG
        Swift.print("🎯 [FaceDetector] Starting face detection")
        #endif
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored)
        do {
            try handler.perform([request])
            let faces = request.results as? [VNFaceObservation] ?? []
            
            #if DEBUG
            Swift.print("🎯 [FaceDetector] Detection completed, face count: \(faces.count)")
            if let firstFace = faces.first {
                Swift.print("🎯 [FaceDetector] First face box: \(firstFace.boundingBox), confidence: \(firstFace.confidence)")
            }
            #endif
            
            return (faces.count, faces.first?.boundingBox)
        } catch {
            #if DEBUG
            Swift.print("🎯 [FaceDetector] Vision detection error: \(error)")
            #endif
            return (0, nil)
        }
    }
}
