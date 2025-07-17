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
    @Published var statusMessage = "请将脸部对准相机"
    @Published var shouldDismiss = false
    @Published var finalResult: FinalResult = .none
    
    // 处理状态标记
    @Published private var isProcessing = false
    
    var isComparing: Bool {
        get { isProcessingInternal }
        set { 
            #if DEBUG
            if newValue != isProcessingInternal {
                print("🔄 [isComparing] 状态改变: \(isProcessingInternal) -> \(newValue)")
            }
            #endif
            isProcessingInternal = newValue 
        }
    }
    
    // 内部状态
    private var isProcessingInternal = false
    private var successCounter = 0
    private var totalDetections = 0
    
    // 图像处理
    private var _referenceImage: UIImage?
    private var referenceFeaturePrint: VNFeaturePrintObservation?
    
    // 公共访问器
    var referenceImage: UIImage? {
        return _referenceImage
    }
    
    // 常量
    private let maxDetections = 100
    private let successThreshold = 20
    private let similarityThreshold: Float = 0.64
    
    init(referenceImage: UIImage, algorithmName: String? = nil) {
        self._referenceImage = referenceImage
        #if DEBUG
        print("🚀 [FaceComparisonViewModel] 初始化")
        #endif
        loadReferenceImage()
    }
    
    // MARK: - 图像加载
    
    private func loadReferenceImage() {
        #if DEBUG
        print("📸 [loadReferenceImage] 开始加载参考图像")
        #endif
        
        guard let image = _referenceImage else {
            #if DEBUG
            print("❌ [loadReferenceImage] 无法加载参考图像")
            #endif
            return
        }
        
        // 异步提取参考图像的特征
        Task {
            await extractReferenceFeatures()
        }
    }
    
    private func extractReferenceFeatures() async {
        guard let image = _referenceImage else { return }
        
        do {
            referenceFeaturePrint = try await extractFeaturePrint(from: image)
            #if DEBUG
            print("✅ [extractReferenceFeatures] 参考图像特征提取成功")
            #endif
        } catch {
            #if DEBUG
            print("❌ [extractReferenceFeatures] 参考图像特征提取失败: \(error)")
            #endif
        }
    }
    
    // MARK: - 人脸检测与处理
    
    /// 处理摄像头图像
    func processFaceImage(_ image: UIImage) {
        // 防止重复处理
        guard !isProcessingInternal else { return }
        
        #if DEBUG
        print("🔄 [processFaceImage] 开始处理图像")
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
            print("❌ [processImage] 处理失败: \(error)")
            #endif
            noFaceDetected()
        }
    }
    
    /// 特征提取
    private func extractFeaturePrint(from image: UIImage) async throws -> VNFeaturePrintObservation? {
        return try await withCheckedThrowingContinuation { continuation in
            guard let ciImage = CIImage(image: image) else {
                continuation.resume(throwing: NSError(domain: "ImageProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建CIImage"]))
                return
            }
            
            // 首先进行人脸检测
            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 处理检测到的人脸
                let faces = request.results as? [VNFaceObservation] ?? []
                
                var processedImage = ciImage
                
                // 如果检测到人脸，裁剪人脸区域
                if let face = faces.first {
                    let boundingBox = face.boundingBox
                    let imageSize = ciImage.extent.size
                    
                    // 转换Vision坐标系到图像坐标系
                    let faceRect = CGRect(
                        x: boundingBox.origin.x * imageSize.width,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
                        width: boundingBox.width * imageSize.width,
                        height: boundingBox.height * imageSize.height
                    )
                    
                    // 扩展人脸区域边界，包含更多上下文
                    let expandedRect = faceRect.insetBy(dx: -faceRect.width * 0.2, dy: -faceRect.height * 0.2)
                    let clampedRect = expandedRect.intersection(ciImage.extent)
                    
                    if !clampedRect.isEmpty && clampedRect.width > 50 && clampedRect.height > 50 {
                        processedImage = ciImage.cropped(to: clampedRect)
                        
                        #if DEBUG
                        print("✅ [extractFeaturePrint] 成功裁剪人脸区域: \(clampedRect)")
                        #endif
                    }
                }
                
                // 使用处理后的图像进行特征提取
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
    
    /// 比较特征
    private func compareFeatures(_ currentFeaturePrint: VNFeaturePrintObservation) async {
        guard let referenceFeaturePrint = referenceFeaturePrint else {
            #if DEBUG
            print("⚠️ [compareFeatures] 参考特征不存在")
            #endif
            noFaceDetected()
            return
        }
        
        do {
            var distanceValue: Float = 0
            try referenceFeaturePrint.computeDistance(&distanceValue, to: currentFeaturePrint)
            
            #if DEBUG
            print("📊 [compareFeatures] 计算距离: \(distanceValue)")
            #endif
            
            totalDetections += 1
            distance = distanceValue
            
            if distanceValue <= similarityThreshold {
                successCounter += 1
                comparisonResult = .match
                statusMessage = String(format: "匹配成功! 距离: %.4f (成功: %d/%d)", distanceValue, successCounter, totalDetections)
                
                #if DEBUG
                print("✅ [compareFeatures] 匹配成功! 距离: \(distanceValue)")
                #endif
            } else {
                // 如果距离超过1，减少successCounter
                if distanceValue > 1.0 {
                    successCounter -= 1
                }
                comparisonResult = .noMatch
                statusMessage = String(format: "不匹配。距离: %.4f (成功: %d/%d)", distanceValue, successCounter, totalDetections)
                
                #if DEBUG
                print("❌ [compareFeatures] 不匹配。距离: \(distanceValue)")
                #endif
            }
            
            checkEndConditions()
            
        } catch {
            #if DEBUG
            print("❌ [compareFeatures] 距离计算失败: \(error)")
            #endif
            noFaceDetected()
        }
    }
    
    /// 当没有检测到人脸时调用
    func noFaceDetected() {
        guard !isProcessingInternal else { return }
        
        #if DEBUG
        print("👤 [noFaceDetected] 未检测到人脸")
        #endif
        
        totalDetections += 1
        
        distance = .greatestFiniteMagnitude
        comparisonResult = .waiting
        statusMessage = String(format: "未检测到人脸 (计数: %d/%d)", successCounter, totalDetections)
        
        // 检查是否达到最大检测次数
        checkEndConditions()
    }
    
    /// 检查结束条件
    private func checkEndConditions() {
        #if DEBUG
        print("🔍 [checkEndConditions] 检查结束条件 - 成功: \(successCounter)/\(successThreshold), 总数: \(totalDetections)/\(maxDetections)")
        #endif
        
        // 如果successCounter达到20，立即成功
        if successCounter >= successThreshold {
            finalResult = .success
            statusMessage = String(format: "验证成功! 匹配次数: %d/%d", successCounter, totalDetections)
            
            #if DEBUG
            print("🎉 [checkEndConditions] 立即验证成功!")
            #endif
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.shouldDismiss = true
            }
        } else if totalDetections >= maxDetections {
            // 当全部检测执行完时，只要successCounter大于10就判定为成功
            if successCounter > 10 {
                finalResult = .success
                statusMessage = String(format: "验证成功! 匹配次数: %d/%d", successCounter, totalDetections)
                
                #if DEBUG
                print("🎉 [checkEndConditions] 检测完成后验证成功!")
                #endif
            } else {
                finalResult = .failure
                statusMessage = String(format: "验证失败。匹配次数: %d/%d", successCounter, totalDetections)
                
                #if DEBUG
                print("💔 [checkEndConditions] 验证失败")
                #endif
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.shouldDismiss = true
            }
        }
    }
    
    /// 重置状态
    func reset() {
        #if DEBUG
        print("🔄 [reset] 重置状态")
        #endif
        
        isProcessingInternal = false
        successCounter = 0
        totalDetections = 0
        distance = .greatestFiniteMagnitude
        comparisonResult = .waiting
        statusMessage = "请将脸部对准相机"
        shouldDismiss = false
        finalResult = .none
    }
}