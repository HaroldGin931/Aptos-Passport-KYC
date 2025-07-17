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

// MARK: - CameraManager —— 负责采集像素缓冲并发布
final class CameraManager: NSObject, ObservableObject {
    
    @Published var latestPixelBuffer: CVPixelBuffer?     // 最新视频帧
    @Published var session = AVCaptureSession()          // 公开发布 session
    @Published var isRunning = false                     // 摄像头运行状态
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "cam.queue", qos: .userInitiated)
    
    override init() {
        super.init()
        setupCamera()
    }
    
    /// 设置摄像头配置
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
    
    /// 启动摄像头
    func start() {
        guard !isRunning else { 
            #if DEBUG
            Swift.print("📹 [CameraManager] 摄像头已在运行，跳过启动")
            #endif
            return 
        }
        
        #if DEBUG
        Swift.print("📹 [CameraManager] 开始启动摄像头")
        #endif
        
        sessionQueue.async {
            #if DEBUG
            Swift.print("📹 [CameraManager] 在session队列中启动摄像头")
            #endif
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
                #if DEBUG
                Swift.print("📹 [CameraManager] 摄像头启动完成，状态已更新")
                #endif
            }
        }
    }
    
    /// 停止摄像头
    func stop() {
        guard isRunning else { 
            #if DEBUG
            Swift.print("📹 [CameraManager] 摄像头已停止，跳过停止操作")
            #endif
            return 
        }
        
        #if DEBUG
        Swift.print("📹 [CameraManager] 开始停止摄像头")
        #endif
        
        sessionQueue.async {
            #if DEBUG
            Swift.print("📹 [CameraManager] 在session队列中停止摄像头")
            #endif
            
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isRunning = false
                #if DEBUG
                Swift.print("📹 [CameraManager] 摄像头停止完成，状态已更新")
                #endif
            }
        }
    }
    
    /// 从当前帧中提取人脸图像
    func extractFaceImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        #if DEBUG
        Swift.print("🔍 [CameraManager] 开始从像素缓冲区提取人脸图像")
        #endif
        
        var detector = FaceDetector()
        let detection = detector.detect(in: pixelBuffer)
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] 人脸检测结果: 数量=\(detection.count), 第一个框=\(detection.firstBox?.debugDescription ?? "无")")
        #endif
        
        guard let box = detection.firstBox else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] 未检测到人脸，返回nil")
            #endif
            return nil
        }
        
        // 计算像素 ROI (翻转 Y 轴)
        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let rect = CGRect(x: box.origin.x * w,
                          y: (1 - box.origin.y - box.height) * h,
                          width: box.width * w,
                          height: box.height * h)
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] 像素缓冲区尺寸: \(w)x\(h), 人脸框: \(rect)")
        #endif
        
        // 验证边界值的有效性
        guard rect.width > 0 && rect.height > 0 && 
              rect.origin.x >= 0 && rect.origin.y >= 0 && 
              rect.maxX <= w && rect.maxY <= h else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] 人脸框边界无效，返回nil")
            #endif
            return nil
        }
        
        // 从 pixelBuffer 裁出 ROI -> UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).cropped(to: rect)
        let context = CIContext()
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] 创建CI图像，extent: \(ciImage.extent)")
        #endif
        
        // 确保 CIImage 的 extent 有效
        guard !ciImage.extent.isEmpty else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] CI图像extent为空，返回nil")
            #endif
            return nil
        }
        
        guard let cgFace = context.createCGImage(ciImage, from: ciImage.extent) else {
            #if DEBUG
            Swift.print("🔍 [CameraManager] 创建CG图像失败，返回nil")
            #endif
            return nil
        }
        
        #if DEBUG
        Swift.print("🔍 [CameraManager] 成功提取人脸图像，尺寸: \(cgFace.width)x\(cgFace.height)")
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
        Swift.print("📹 [CameraManager] 接收到新视频帧，时间戳: \(timestamp.seconds)")
        #endif
        
        DispatchQueue.main.async {
            self.latestPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            #if DEBUG
            Swift.print("📹 [CameraManager] 视频帧已更新到主线程")
            #endif
        }
    }
}

// MARK: - FaceDetector —— 只负责返回人脸框数量与第一个框
struct FaceDetector {
    
    private let request = VNDetectFaceRectanglesRequest()
    
    mutating func detect(in pixelBuffer: CVPixelBuffer) -> (count: Int, firstBox: CGRect?) {
        #if DEBUG
        Swift.print("🎯 [FaceDetector] 开始人脸检测")
        #endif
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored)
        do {
            try handler.perform([request])
            let faces = request.results as? [VNFaceObservation] ?? []
            
            #if DEBUG
            Swift.print("🎯 [FaceDetector] 检测完成，人脸数量: \(faces.count)")
            if let firstFace = faces.first {
                Swift.print("🎯 [FaceDetector] 第一个人脸框: \(firstFace.boundingBox), 置信度: \(firstFace.confidence)")
            }
            #endif
            
            return (faces.count, faces.first?.boundingBox)
        } catch {
            #if DEBUG
            Swift.print("🎯 [FaceDetector] Vision检测错误: \(error)")
            #endif
            return (0, nil)
        }
    }
}
