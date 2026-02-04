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
        // ❌ 删除 setupObservers()，防止后台切前台时自动启动
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
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
            // 防止重复配置
            if !self.session.inputs.isEmpty { return }
            
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
            // ❌ 注意：配置完成后不自动 startRunning，等待按钮点击
        }
    }
    
    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning { return }
            
            let photoSettings = AVCapturePhotoSettings()
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
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
        // ❌ 修复：reset 时不要自动 start，等待外部显式调用
        // self.start()
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

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        Task { @MainActor in
            self.stop() // ✅ 拍照后立即停止相机流
            self.capturedImage = image
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
        
        if #available(iOS 17.0, *) {
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
