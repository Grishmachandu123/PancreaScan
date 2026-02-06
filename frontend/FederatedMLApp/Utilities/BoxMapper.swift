//  BoxMapper.swift
//  Utility to map YOLO coordinates to image space

import Foundation
import CoreGraphics

struct BoxMapper {
    /// Maps YOLO bounding box coordinates from model space to original image space
    /// - Parameters:
    ///   - box: Bounding box in model coordinate space
    ///   - modelSize: Model input size (e.g., 512 or 640)
    ///   - imageSize: Original image size
    /// - Returns: Bounding box in original image coordinate space
    static func mapYOLOBoxToImageSpace(box: CGRect, modelSize: CGFloat, imageSize: CGSize) -> CGRect {
        // Calculate scale factor (account for aspect ratio preservation)
        let scaleX = imageSize.width / modelSize
        let scaleY = imageSize.height / modelSize
        let _ = min(scaleX, scaleY)
        
        // Calculate padding if image was letterboxed
        let scaledWidth = modelSize * scaleX
        let scaledHeight = modelSize * scaleY
        let padX = (scaledWidth - imageSize.width) / 2
        let padY = (scaledHeight - imageSize.height) / 2
        
        // Map coordinates
        let x = (box.origin.x * scaleX) - padX
        let y = (box.origin.y * scaleY) - padY
        let width = box.width * scaleX
        let height = box.height * scaleY
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Alternative: Simple proportional scaling (no letterbox)
    static func mapBoxProportional(box: CGRect, modelSize: CGFloat, imageSize: CGSize) -> CGRect {
        let scaleX = imageSize.width / modelSize
        let scaleY = imageSize.height / modelSize
        
        return CGRect(
            x: box.origin.x * scaleX,
            y: box.origin.y * scaleY,
            width: box.width * scaleX,
            height: box.height * scaleY
        )
    }
}
