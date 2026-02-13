//
//  CameraView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 1. Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var permissionGranted = false
    @Published var isSessionReady = false // 🚀 新增：session 配置完成标志
    @Published var isTorchOn = false

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)

    private var isSessionConfigured = false
    private var videoDeviceInput: AVCaptureDeviceInput?

    override init() {
        super.init()
        checkPermission()
    }

    deinit {
        // 🔥 FIX: 使用 async 而不是 sync 避免在 deinit 中死锁
        let session = self.session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
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
            if self.isSessionConfigured { return }
            if !self.session.inputs.isEmpty { return }

            self.session.beginConfiguration()

            // 🚀 优化：使用 photo preset 获得最佳质量
            self.session.sessionPreset = .photo

            // 🚀 优化：获取最佳可用设备
            let videoDevice = self.bestAvailableDevice()

            guard let device = videoDevice,
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(videoDeviceInput) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput

            // 🚀 优化：配置设备以获得更快的对焦
            self.configureDevice(device)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)

                // 设置照片方向
                if let connection = self.photoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                    } else {
                        connection.videoOrientation = .portrait
                    }
                }
            }

            self.session.commitConfiguration()
            self.isSessionConfigured = true

            DispatchQueue.main.async {
                self.isSessionReady = true
            }

            print("✅ [Camera] Session 配置完成")
        }
    }

    // 🚀 新增：获取最佳可用相机设备
    private func bestAvailableDevice() -> AVCaptureDevice? {
        // 优先使用广角相机
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        // 回退到任何可用的后置相机
        return AVCaptureDevice.default(for: .video)
    }

    // 🚀 新增：优化设备配置
    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // 启用连续自动对焦
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // 启用连续自动曝光
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            // 启用低光增强
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            device.unlockForConfiguration()
        } catch {
            print("⚠️ [Camera] 设备配置失败: \(error)")
        }
    }

    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }

            let photoSettings = AVCapturePhotoSettings()

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.capturedImage = nil
        }
    }

    func setTorch(enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let applied = self.setTorchOnSessionQueue(enabled: enabled)
            DispatchQueue.main.async {
                self.isTorchOn = applied
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.setTorchOnSessionQueue(enabled: false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isTorchOn = false
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning && self.isSessionConfigured {
                self.session.startRunning()
            }
        }
    }

    private func setTorchOnSessionQueue(enabled: Bool) -> Bool {
        guard let device = videoDeviceInput?.device,
              device.hasTorch else {
            return false
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if enabled {
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    return true
                } else {
                    return false
                }
            } else {
                device.torchMode = .off
                return false
            }
        } catch {
            print("⚠️ [Camera] Torch toggle failed: \(error)")
            return false
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ [Camera] Error capturing photo: \(error)")
            return
        }

        // 在当前线程获取图片数据
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        Task { @MainActor in
            self.stop()
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

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 🚀 优化：确保 session 正确连接
        if uiView.videoPreviewLayer.session !== cameraManager.session {
            uiView.videoPreviewLayer.session = cameraManager.session
        }
    }
}
