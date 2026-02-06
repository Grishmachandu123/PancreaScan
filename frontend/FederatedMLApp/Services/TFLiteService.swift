//  TFLiteService.swift
//  TensorFlow Lite inference service for YOLOv8 segmentation

import UIKit
import TensorFlowLite
import CoreGraphics
import Accelerate

/// Result from TFLite inference
struct YOLODetection: Equatable, Codable {
    let bbox: CGRect  // Normalized coordinates [0-1]
    let confidence: Float
    let classId: Int
    let className: String
    let mask: [Float]?  // Optional segmentation mask
    
    static func == (lhs: YOLODetection, rhs: YOLODetection) -> Bool {
        return lhs.bbox == rhs.bbox &&
               lhs.confidence == rhs.confidence &&
               lhs.classId == rhs.classId &&
               lhs.className == rhs.className
    }
}

/// TensorFlow Lite service for YOLOv8 segmentation model
class TFLiteService {
    static let shared = TFLiteService()
    
    // Model configuration (matching server.py)
    private let modelInputSize: Int = 640
    private let confidenceThreshold: Float = 0.25
    private let iouThreshold: Float = 0.45
    private let minAreaFraction: Float = 0.005
    
    private var inputWidth: Int = 640
    private var inputHeight: Int = 640
    
    private var interpreter: Interpreter?
    private let classNames = ["ABNORMAL", "normal"]
    
    init() {
        loadModel()
    }
    
    func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "pancreas", ofType: "tflite") else {
            print("❌ Failed to load model: pancreas.tflite")
            return
        }
        
        do {
            // Initialize interpreter
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
            
            // Get input tensor details to determine size dynamically
            if let inputTensor = try interpreter?.input(at: 0) {
                let shape = inputTensor.shape
                
                // Shape is usually [1, H, W, 3] or [1, 3, H, W]
                if shape.dimensions.count == 4 {
                    // Assuming NHWC: [Batch, Height, Width, Channels]
                    if shape.dimensions[3] == 3 {
                        inputHeight = shape.dimensions[1]
                        inputWidth = shape.dimensions[2]
                    } else if shape.dimensions[1] == 3 {
                        inputHeight = shape.dimensions[2]
                        inputWidth = shape.dimensions[3]
                    }
                }
                print("✅ Model loaded. Input size: \(inputWidth)x\(inputHeight)")
                print("   Input shape: \(inputTensor.shape)")
                print("   Input type: \(inputTensor.dataType)")
            }
            
            if let outputCount = interpreter?.outputTensorCount {
                print("   Output tensors: \(outputCount)")
                for i in 0..<outputCount {
                    if let outputTensor = try? interpreter?.output(at: i) {
                        print("   Output \(i) shape: \(outputTensor.shape)")
                    }
                }
            }
        } catch {
            print("❌ Failed to load TFLite model: \(error)")
        }
    }
    
    // MARK: - Inference
    
    func predict(image: UIImage, completion: @escaping (Result<[YOLODetection], Error>) -> Void) {
        guard let interpreter = interpreter else {
            completion(.failure(TFLiteError.modelNotLoaded))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. Preprocess image
                guard let inputData = self.preprocessImage(image) else {
                    throw TFLiteError.preprocessingFailed
                }
                
                // 2. Run inference
                try interpreter.copy(inputData, toInputAt: 0)
                try interpreter.invoke()
                
                // 3. Get output tensors
                let outputTensor0 = try interpreter.output(at: 0)
                let outputTensor1 = try interpreter.output(at: 1)
                
                // 4. Parse detections
                // Get prototype shape dynamically
                let protoShape = outputTensor1.shape.dimensions
                
                let detections = self.parseOutput(
                    output0: outputTensor0.data,
                    output1: outputTensor1.data,
                    protoShape: protoShape,
                    imageSize: image.size,
                    modelInputSize: self.inputWidth // Use dynamic input size
                )
                
                // 5. Apply NMS and filtering
                let filteredDetections = self.applyNMS(detections)
                
                DispatchQueue.main.async {
                    completion(.success(filteredDetections))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Store letterbox info for coordinate mapping
    private var letterboxScale: CGFloat = 1.0
    private var letterboxOffsetX: CGFloat = 0.0
    private var letterboxOffsetY: CGFloat = 0.0
    
    private func preprocessImage(_ image: UIImage) -> Data? {
        // IMPORTANT: Normalize image orientation first to fix coordinate system
        guard let normalizedImage = image.normalizedImage() else {
            print("⚠️ Failed to normalize image orientation")
            return nil
        }
        
        // Simple resize to match model input size (Stretching)
        let targetSize = CGSize(width: inputWidth, height: inputHeight)
        
        guard let resizedImage = normalizedImage.resizeExact(to: targetSize) else {
            return nil
        }
        
        guard let cgImage = resizedImage.cgImage else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create pixel buffer
        // Create pixel buffer with explicit RGBA layout (Big Endian: R G B A)
        // This ensures Byte 0 is Red, Byte 1 is Green, Byte 2 is Blue
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else {
            return nil
        }
        
        // Convert to NHWC format [1, 640, 640, 3] - matching model input shape and server.py
        // Model expects: [Batch, Height, Width, Channels]
        var floatArray = [Float](repeating: 0, count: width * height * 3)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = ((y * width) + x) * 4
                
                // Read RGB values (We forced RGBA layout above)
                let r = Float(pixelData.load(fromByteOffset: pixelIndex, as: UInt8.self))
                let g = Float(pixelData.load(fromByteOffset: pixelIndex + 1, as: UInt8.self))
                let b = Float(pixelData.load(fromByteOffset: pixelIndex + 2, as: UInt8.self))
                
                // NHWC format: [Height, Width, Channels]
                // Index = (y * width * 3) + (x * 3) + channel
                let nhwcIndex = (y * width * 3) + (x * 3)
                floatArray[nhwcIndex + 0] = r / 255.0
                floatArray[nhwcIndex + 1] = g / 255.0
                floatArray[nhwcIndex + 2] = b / 255.0
            }
        }
        
        print("🔬 Preprocessed image: \(width)x\(height), NHWC format (RGB forced), normalized [0,1]")
        
        return Data(bytes: floatArray, count: floatArray.count * MemoryLayout<Float>.stride)
    }
    
    // MARK: - Postprocessing
    
    private func parseOutput(output0: Data, output1: Data, protoShape: [Int], imageSize: CGSize, modelInputSize: Int) -> [YOLODetection] {
        var detections: [YOLODetection] = []
        
        print("🖼️ Image sizes: original=\(imageSize), model=\(inputWidth)x\(inputHeight)")
        
        // Output0 shape: [1, 38, 5376] (or similar)
        // Output1 shape: protoShape (e.g., [1, 128, 128, 32] or [1, 32, 128, 128])
        
        // Convert Data to Float arrays
        let floatArray = output0.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        
        let _ = output1.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        
        // Determine number of anchors from output0 size
        // floatArray count = 1 * 38 * numAnchors
        // numAnchors = count / 38
        // But 38 is (4 box + 2 class + 32 mask). This might vary if classes change.
        // Let's assume 38 for now based on previous code, or calculate it.
        // If we know numAnchors is usually ~5376 or ~8400.
        // Let's rely on the known structure: [1, Channels, Anchors]
        // Channels = 4 + numClasses + numMasks = 4 + 2 + 32 = 38
        let numChannels = 38
        let numAnchors = floatArray.count / numChannels
        
        print("🔬 Parsing output: \(numAnchors) anchors, channels=\(numChannels)")
        print("📦 Proto shape: \(protoShape)")
        
        // Find max box value to check if normalized (matching server.py line 143)
        var maxBoxValue: Float = 0.0
        for i in 0..<numAnchors {
            let cx = floatArray[0 * numAnchors + i]
            let cy = floatArray[1 * numAnchors + i]
            let w = floatArray[2 * numAnchors + i]
            let h = floatArray[3 * numAnchors + i]
            maxBoxValue = max(maxBoxValue, cx, cy, w, h)
        }
        print("🔍 DEBUG: Max Box Value: \(maxBoxValue)")
        
        // Check if coordinates are normalized (use <= 2.0 to handle edge cases where some anchors slightly exceed 1.0)
        // If max value is small (< 2), coordinates are likely in 0-1 normalized space
        let isNormalized = maxBoxValue <= 2.0
        if isNormalized {
            print("🔍 DEBUG: Detected normalized coordinates (0-1). Will scale by input size (\(inputWidth)).")
        } else {
            print("🔍 DEBUG: Coordinates appear to be in pixel space (0-\(inputWidth)).")
        }
        
        // Extract boxes and classes (matching Python logic)
        var boxes: [(cx: Float, cy: Float, w: Float, h: Float)] = []
        var scores: [Float] = []
        var classIds: [Int] = []
        
        // Process each anchor
        for i in 0..<numAnchors {
            // Get box coordinates (indices 0-3)
            var cx = floatArray[0 * numAnchors + i]
            var cy = floatArray[1 * numAnchors + i]
            var w = floatArray[2 * numAnchors + i]
            var h = floatArray[3 * numAnchors + i]
            
            // Get class scores (indices 4-5)
            let score0 = floatArray[4 * numAnchors + i] // ABNORMAL
            let score1 = floatArray[5 * numAnchors + i] // normal
            
            let maxScore = max(score0, score1)
            let classId = score0 > score1 ? 0 : 1
            
            // Filter by confidence threshold
            if maxScore >= confidenceThreshold {
                // Scale normalized coordinates to model input size (matching server.py line 149-152)
                if isNormalized {
                    cx *= Float(inputWidth)
                    cy *= Float(inputHeight)
                    w *= Float(inputWidth)
                    h *= Float(inputHeight)
                }
                
                boxes.append((cx, cy, w, h))
                scores.append(maxScore)
                classIds.append(classId)
            }
        }
        
        print("📊 Detections > \(confidenceThreshold): \(boxes.count)")
        
        // Removed "force include best detection" logic to prevent showing low-confidence garbage
        // If no detections meet threshold, we should return empty list
        
        // Convert to corner format and create detections (matching server.py line 169-178)
        for (idx, box) in boxes.enumerated() {
            let cx = box.cx
            let cy = box.cy
            let w = box.w
            let h = box.h
            
            // Convert from center (cx, cy, w, h) to corners (x1, y1, x2, y2)
            // These are now in model input space (0-640)
            let x1 = cx - w / 2
            let y1 = cy - h / 2
            let x2 = cx + w / 2
            let y2 = cy + h / 2
            
            // Skip invalid boxes
            if w <= 0 || h <= 0 { continue }
            
            // Scale from model input space to original image space (matching server.py line 212-215)
            let scaleX = Float(imageSize.width) / Float(inputWidth)
            let scaleY = Float(imageSize.height) / Float(inputHeight)
            
            let scaledX1 = x1 * scaleX
            let scaledY1 = y1 * scaleY
            let scaledX2 = x2 * scaleX
            let scaledY2 = y2 * scaleY
            
            let mappedRect = CGRect(
                x: CGFloat(scaledX1),
                y: CGFloat(scaledY1),
                width: CGFloat(scaledX2 - scaledX1),
                height: CGFloat(scaledY2 - scaledY1)
            )
            
            print("🔍 DEBUG: Box \(idx) - model space: (\(x1), \(y1), \(x2), \(y2)) -> image space: \(mappedRect)")
            
            // Skip mask generation since we're only doing bounding boxes
            let detection = YOLODetection(
                bbox: mappedRect,
                confidence: scores[idx],
                classId: classIds[idx],
                className: classNames[classIds[idx]],
                mask: nil
            )
            
            detections.append(detection)
        }
        
        return detections
    }
    
    private func generateMask(coeffs: [Float], protoData: [Float], protoShape: [Int]) -> [Float] {
        // protoShape is usually [1, 128, 128, 32] (NHWC) or [1, 32, 128, 128] (NCHW)
        // We need to determine dimensions dynamically
        
        var maskWidth = 128
        var maskHeight = 128
        var numProtos = 32
        var isNHWC = true
        
        if protoShape.count == 4 {
            if protoShape[3] == 32 {
                // NHWC: [Batch, H, W, Channels]
                maskHeight = protoShape[1]
                maskWidth = protoShape[2]
                numProtos = protoShape[3]
                isNHWC = true
            } else if protoShape[1] == 32 {
                // NCHW: [Batch, Channels, H, W]
                numProtos = protoShape[1]
                maskHeight = protoShape[2]
                maskWidth = protoShape[3]
                isNHWC = false
            }
        }
        
        let numPixels = maskWidth * maskHeight
        var mask = [Float](repeating: 0.0, count: numPixels)
        
        // Matrix multiplication: Mask = Sigmoid(Coeffs * Protos)
        // Coeffs: [1, 32]
        // Protos: [32, 128*128] (flattened appropriately)
        
        if isNHWC {
            // NHWC: Protos are [H, W, C] -> [Pixel, Channel]
            // Index = (y * width + x) * numProtos + p
            for p in 0..<numProtos {
                let coeff = coeffs[p]
                for i in 0..<numPixels {
                    mask[i] += coeff * protoData[i * numProtos + p]
                }
            }
        } else {
            // NCHW: Protos are [C, H, W] -> [Channel, Pixel]
            // Index = p * numPixels + i
            for p in 0..<numProtos {
                let coeff = coeffs[p]
                for i in 0..<numPixels {
                    mask[i] += coeff * protoData[p * numPixels + i]
                }
            }
        }
        
        // Sigmoid activation
        for i in 0..<numPixels {
            mask[i] = 1.0 / (1.0 + exp(-mask[i]))
        }
        
        return mask
    }
    
    
    // MARK: - NMS (Non-Maximum Suppression)
    
    private func applyNMS(_ detections: [YOLODetection]) -> [YOLODetection] {
        if detections.isEmpty {
            return []
        }
        
        print("🔍 NMS: Input \(detections.count) detections")
        
        // Sort by confidence (descending)
        let sortedDetections = detections.sorted { $0.confidence > $1.confidence }
        
        // Print top 3 for debugging
        for (i, det) in sortedDetections.prefix(3).enumerated() {
            print("  #\(i): conf=\(det.confidence), class=\(det.className), bbox=\(det.bbox)")
        }
        
        var selectedDetections: [YOLODetection] = []
        var suppressed = Set<Int>()
        
        for i in 0..<sortedDetections.count {
            if suppressed.contains(i) {
                continue
            }
            
            let detection = sortedDetections[i]
            selectedDetections.append(detection)
            
            // Suppress overlapping detections OF THE SAME CLASS
            var suppressedCount = 0
            for j in (i + 1)..<sortedDetections.count {
                if suppressed.contains(j) {
                    continue
                }
                
                // Only suppress if same class
                if detection.classId != sortedDetections[j].classId {
                    continue
                }
                
                let iou = calculateIOU(detection.bbox, sortedDetections[j].bbox)
                if iou > iouThreshold {
                    suppressed.insert(j)
                    suppressedCount += 1
                }
            }
            
            if suppressedCount > 0 {
                print("  ✂️ Detection #\(i) (\(detection.className)) suppressed \(suppressedCount) overlapping boxes of same class")
            }
        }
        
        print("✅ NMS: Output \(selectedDetections.count) detections")
        
        // Return only the single best detection (highest confidence) - matching server.py
        if let best = sortedDetections.first {
            print("🎯 Best detection: \(best.className) \(String(format: "%.1f", best.confidence * 100))% at \(best.bbox)")
            return [best]
        }
        return []
    }
    
    private func calculateIOU(_ box1: CGRect, _ box2: CGRect) -> Float {
        let intersection = box1.intersection(box2)
        if intersection.isNull {
            return 0.0
        }
        
        let intersectionArea = intersection.width * intersection.height
        let union = box1.width * box1.height + box2.width * box2.height - intersectionArea
        
        return Float(intersectionArea / union)
    }
}

// MARK: - Error Types

enum TFLiteError: Error {
    case modelNotLoaded
    case preprocessingFailed
    case inferenceFailed
    case postprocessingFailed
    
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "TFLite model is not loaded"
        case .preprocessingFailed:
            return "Failed to preprocess image"
        case .inferenceFailed:
            return "Model inference failed"
        case .postprocessingFailed:
            return "Failed to parse model output"
        }
    }
}

// MARK: - Helper Extensions

extension UIImage {
    func resizeExact(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    func resizeWithLetterbox(to size: CGSize) -> UIImage? {
        let aspectRatio = self.size.width / self.size.height
        let targetRatio = size.width / size.height
        
        var newSize: CGSize
        if aspectRatio > targetRatio {
            // Image is wider
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // Image is taller
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        let xOffset = (size.width - newSize.width) / 2
        let yOffset = (size.height - newSize.height) / 2
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Fill with gray (letterbox)
        UIColor(white: 0.5, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Draw image
        draw(in: CGRect(x: xOffset, y: yOffset, width: newSize.width, height: newSize.height))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
}

extension Data {
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
    
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = [T](repeating: 0, count: self.count / MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { self.copyBytes(to: $0) }
        return array
    }
}
