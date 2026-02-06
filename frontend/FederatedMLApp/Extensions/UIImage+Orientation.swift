//  UIImage+Orientation.swift
//  Extension to fix UIImage orientation issues

import UIKit

extension UIImage {
    /// Returns a normalized image with orientation corrected
    /// This fixes coordinate system issues when images have EXIF orientation data
    func normalizedImage() -> UIImage? {
        // If image is already in correct orientation, return it
        if imageOrientation == .up {
            return self
        }
        
        // Create graphics context with proper orientation
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
