//
//  CameraView.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//


import SwiftUI
import UIKit

// 这是一个“桥梁”，把 UIKit 的相机功能包装给 SwiftUI 使用
struct CameraView: UIViewControllerRepresentable {
    
    // 用来把拍到的照片传回给父视图
    @Binding var selectedImage: UIImage?
    // 用来控制相机界面的关闭
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // 核心设置：使用相机，而不是相册
        // 如果是在模拟器上跑，这里会崩溃（模拟器没相机），所以为了安全可以加个判断
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            print("⚠️ 警告：当前设备不支持相机，正在回退到相册模式")
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 协调器：负责处理“拍完照片后干什么”
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 拿到原始照片
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            // 关闭相机界面
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}