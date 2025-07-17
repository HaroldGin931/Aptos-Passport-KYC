//
//  CameraPreviewView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/17.
//

import SwiftUI
import AVFoundation

// MARK: - CameraPreview —— 将 AVCaptureSession 画面嵌入 SwiftUI
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
    
    /// 内部 UIView 子类，自动填充 layer
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
            videoPreviewLayer.videoGravity = .resizeAspectFill
        }
    }
}

#Preview {
    CameraPreviewView(session: AVCaptureSession())
        .frame(height: 320)
        .cornerRadius(8)
}