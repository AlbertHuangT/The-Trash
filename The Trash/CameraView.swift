//
//  CameraView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 1. Camera Manager (相机逻辑控制器)
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var permissionGranted = false
    
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 已经授权
            DispatchQueue.main.async { self.permissionGranted = true }
            self.setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionGranted = false }
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(videoDeviceInput)
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.commitConfiguration()
            // 修改点：初始化后不自动启动流，等待 View 层明确调用 start()
            // self.session.startRunning()
        }
    }
    
    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning { return }
            
            let photoSettings = AVCapturePhotoSettings()
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                // 🔥 Fix: 修复 iOS 17 videoOrientation 过期警告
                if #available(iOS 17.0, *) {
                    // 90度通常对应 Portrait，具体取决于设备方向逻辑
                    if photoOutputConnection.isVideoRotationAngleSupported(90) {
                        photoOutputConnection.videoRotationAngle = 90
                    }
                } else {
                    photoOutputConnection.videoOrientation = .portrait
                }
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.capturedImage = nil
        }
        self.start()
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
}

// 🔥 Fix: 标记为 nonisolated 以符合 Swift 6 并发要求
// 因为这个代理方法是由 AVFoundation 在任意线程调用的
extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        // 拍照后停止流（定格）
        // 注意：访问 self.session 需要回到 sessionQueue 或 MainActor，
        // 但这里我们直接用 Task @MainActor 来更新 UI 和停止 Session
        Task { @MainActor in
            self.stop() // 停止预览流
            self.capturedImage = image // 更新 UI 显示照片
        }
    }
}

// MARK: - 2. Camera Preview View
struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // 🔥 Fix: 修复 iOS 17 videoOrientation 过期警告
        if #available(iOS 17.0, *) {
            // iOS 17+ 预览层通常会自动处理，或者使用 RotationAngle
            if view.videoPreviewLayer.connection?.isVideoRotationAngleSupported(90) == true {
                view.videoPreviewLayer.connection?.videoRotationAngle = 90
            }
        } else {
            view.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}
