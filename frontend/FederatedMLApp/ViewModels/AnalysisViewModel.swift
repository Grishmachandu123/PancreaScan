//  AnalysisViewModel.swift
//  Handles image analysis with offline/online mode

import Foundation
import UIKit
import Combine

class AnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: AnalysisResult?
    @Published var errorMessage: String?
    
    // Track current analysis to prevent duplicates
    private var currentAnalysisKey: String?
    
    func analyzeImage(_ image: UIImage, patientId: String, patientName: String, physicianId: UUID) {
        // GUARD: Prevent multiple concurrent analyses
        guard !isAnalyzing else {
            print("⚠️ Analysis already in progress, ignoring duplicate request")
            return
        }
        
        // GUARD: Prevent duplicate analysis for same patient within same session
        let analysisKey = "\(patientId)_\(Date().timeIntervalSince1970)"
        if let current = currentAnalysisKey, current == analysisKey {
            print("⚠️ Duplicate analysis request for same patient, ignoring")
            return
        }
        currentAnalysisKey = analysisKey
        
        isAnalyzing = true
        errorMessage = nil
        
        // Validate Image
        if let validationError = ImageQualityAnalyzer.validateImage(image) {
            errorMessage = validationError
            isAnalyzing = false
            currentAnalysisKey = nil
            return
        }
        
        // Always use Local TFLite Inference
        TFLiteService.shared.predict(image: image) { [weak self] result in
            self?.handlePredictionResult(result, image: image, patientId: patientId, patientName: patientName)
            self?.currentAnalysisKey = nil
        }
    }
    
    private func handlePredictionResult(_ result: Result<[YOLODetection], Error>,
                                       image: UIImage,
                                       patientId: String,
                                       patientName: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isAnalyzing = false
            
            // Check image quality
            let qualityWarnings = ImageQualityAnalyzer.checkQuality(image: image)
            
            switch result {
            case .success(let detections):
                // Calculate confidence for abnormal and normal detections
                let abnormalConfidence = detections.filter { $0.classId == 0 }.map { $0.confidence }.max() ?? 0.0
                let normalConfidence = detections.filter { $0.classId == 1 }.map { $0.confidence }.max() ?? 0.0
                
                // check for empty detections (invalid scan)
                if detections.isEmpty {
                    self?.errorMessage = "No pancreas structure detected. Please ensure you are uploading a clear Abdominal CT scan showing the pancreas."
                    return
                }

                // Additional Validation: Check if the best detection is unusually small
                // Pancreas in a standard CT slice usually takes up a decent relative area
                let maxArea = detections.map { $0.bbox.width * $0.bbox.height }.max() ?? 0
                let totalArea = image.size.width * image.size.height
                let areaRatio = maxArea / totalArea
                
                if areaRatio < 0.002 { // Too small to be a reliable pancreas detection
                    self?.errorMessage = "The detected structure is too small to be validated as a pancreas. Please provide a more focused abdominal scan."
                    return
                }

                // Determine diagnosis based on abnormal confidence threshold
                let diagnosis: String
                let confidence: Float
                
                // Only classify as ABNORMAL if confidence is > 50%
                if abnormalConfidence > 0.5 {
                    diagnosis = "ABNORMAL"
                    confidence = abnormalConfidence
                } else {
                    // If we have a detection but it's not strongly abnormal, it's Normal
                    // Since we filtered empty detections, we know we have at least one normal or weak-abnormal detection
                    diagnosis = "Normal"
                    confidence = normalConfidence > 0 ? normalConfidence : (1.0 - abnormalConfidence)
                }
                
                // Calculate metrics for the most confident abnormal detection
                var lobulationScore: Float?
                var circularity: Float?
                var convexity: Float?
                
                if let abnormalDetection = detections.first(where: { $0.classId == 0 }),
                   let mask = abnormalDetection.mask {
                    let metrics = MaskAnalyzer.analyze(mask: mask, width: 128, height: 128)
                    lobulationScore = metrics.lobulation
                    circularity = metrics.circularity
                    convexity = metrics.convexity
                }
                
                // Save image to disk
                let imagePath = self?.saveImageToDocuments(image) ?? ""
                
                // Save detections to JSON
                self?.saveDetectionsToJSON(detections, imagePath: imagePath)
                
                // Use a SINGLE timestamp for both local save and server sync
                let analysisTimestamp = Date()
                
                // Save prediction to SQLite
                let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? "unknown"
                let savedId = SQLiteHelper.shared.insertPrediction(
                    imagePath: imagePath,
                    result: diagnosis,
                    confidence: Double(confidence),
                    patientId: patientId,
                    patientName: patientName,
                    userEmail: userEmail,
                    timestamp: analysisTimestamp
                )
                
                print("✅ Prediction saved to SQLite: \(diagnosis) (\(confidence))")
                
                // Mark as synced IMMEDIATELY to prevent SyncManager from re-uploading
                if let id = savedId {
                    SQLiteHelper.shared.markPredictionSynced(id: id)
                    print("✅ Marked record \(id) as synced (preventing duplicate upload)")
                }
                
                // Auto-Sync to PHP Backend using SAME timestamp
                NetworkService.shared.syncScan(
                    image: image,
                    result: diagnosis,
                    confidence: Double(confidence),
                    patientId: patientId,
                    patientName: patientName,
                    timestamp: analysisTimestamp
                ) { syncResult in
                    switch syncResult {
                    case .success(let synced):
                        print("Sync status: \(synced ? "Synced" : "Failed")")
                    case .failure(let error):
                        // If sync failed, mark as unsynced so SyncManager can retry later
                        if let id = savedId {
                            // Don't unmark - we already uploaded once, server might have it
                            print("⚠️ Sync error (record stays synced to avoid duplicate): \(error)")
                        }
                    }
                }
                
                self?.analysisResult = AnalysisResult(
                    id: UUID(),
                    patientId: patientId,
                    patientName: patientName,
                    timestamp: analysisTimestamp,
                    diagnosis: diagnosis,
                    confidence: confidence,
                    detections: detections,
                    inferenceMode: "Local",
                    lobulationScore: lobulationScore,
                    circularity: circularity,
                    convexity: convexity,
                    qualityWarnings: qualityWarnings
                )
                
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveImageToDocuments(_ image: UIImage) -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return ""
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("scans").appendingPathComponent(filename)
        
        // Create scans directory if needed
        try? FileManager.default.createDirectory(at: documentsURL.appendingPathComponent("scans"),
                                                  withIntermediateDirectories: true)
        
        try? data.write(to: fileURL)
        return fileURL.path
    }
    
    private func saveDetectionsToJSON(_ detections: [YOLODetection], imagePath: String) {
        let jsonPath = imagePath.replacingOccurrences(of: ".jpg", with: ".json")
        let url = URL(fileURLWithPath: jsonPath)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(detections)
            try data.write(to: url)
            print("✅ Detections saved to JSON: \(jsonPath)")
        } catch {
            print("Failed to save detections JSON: \(error)")
        }
    }
}

struct ImageQualityAnalyzer {
    static func validateImage(_ image: UIImage) -> String? {
        // 1. Resolution Check (Strict) - REMOVED BY USER REQUEST
        // let minDimension: CGFloat = 224
        // if image.size.width < minDimension || image.size.height < minDimension {
        //     return "Image resolution is too low (Detected: \(Int(image.size.width))x\(Int(image.size.height))). Please upload a CT scan with at least \(Int(minDimension))x\(Int(minDimension)) resolution."
        // }
        
        // 2. CT Scan Likeness Check (Grayscale, Background, and Density Analysis)
        if !isLikelyCTScan(image) {
            return "Invalid Image: The uploaded file does not appear to be a medical CT scan. Please ensure you are uploading a grayscale DICOM-exported Pancreas CT image."
        }
        
        return nil
    }
    
    static func checkQuality(image: UIImage) -> [String] {
        var warnings: [String] = []
        
        // Blur/Noise Check (Variance of Laplacian)
        if let cgImage = image.cgImage {
            let variance = calculateVariance(cgImage: cgImage)
            if variance < 50 { 
                warnings.append("Image appears blurry. Results may be less accurate.")
            }
        }
        
        return warnings
    }
    
    static func isLikelyCTScan(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        // Resize to small thumbnail for analysis to save memory/time
        let width = 64
        let height = 64
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return true } 
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return true }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var grayscalePixels = 0
        var darkPixels = 0
        var highIntensityPixels = 0
        let totalPixels = width * height
        let grayscaleThreshold = 15 
        let darkThreshold = 30 // Threshold for "background" black
        let highThreshold = 200 // Threshold for "bone/structure" white
        
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Int(ptr[offset])
            let g = Int(ptr[offset + 1])
            let b = Int(ptr[offset + 2])
            
            // 1. Grayscale Check
            if abs(r - g) < grayscaleThreshold && abs(g - b) < grayscaleThreshold && abs(r - b) < grayscaleThreshold {
                grayscalePixels += 1
            }
            
            // 2. Dark Background Check
            if r < darkThreshold && g < darkThreshold && b < darkThreshold {
                darkPixels += 1
            }
            
            // 3. High Intensity Check (Bones/Organs)
            if r > highThreshold || g > highThreshold || b > highThreshold {
                highIntensityPixels += 1
            }
        }
        
        let grayscalePercentage = Double(grayscalePixels) / Double(totalPixels)
        let darkPercentage = Double(darkPixels) / Double(totalPixels)
        let highIntensityPercentage = Double(highIntensityPixels) / Double(totalPixels)
        
        print("📊 Image Validation: Gray=\(Int(grayscalePercentage*100))%, Dark=\(Int(darkPercentage*100))%, High=\(Int(highIntensityPercentage*100))%")
        
        // CRITERIA FOR CT SCAN:
        // 1. Must be mostly grayscale (> 85%)
        // 2. Must have a significant dark background (usually > 15-20%)
        // 3. Must have some high intensity regions (usually > 1% for bones/contrast)
        
        let isGrayscale = grayscalePercentage > 0.85
        let hasDarkBackground = darkPercentage > 0.15 && darkPercentage < 0.90 // Too dark means empty image
        let hasStructure = highIntensityPercentage > 0.005 // At least 0.5% high intensity
        
        return isGrayscale && hasDarkBackground && hasStructure
    }
    
    static func calculateVariance(cgImage: CGImage) -> Double {
        // Use Accelerate for performance if possible, or simple pixel iteration
        // For simplicity here, we'll do a basic pixel iteration on a resized thumbnail
        // to avoid heavy computation on full image
        
        let width = 64
        let height = 64
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width, // Grayscale
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 1000 } // Fail safe
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 1000 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        // Calculate mean
        var sum: Double = 0
        for i in 0..<(width * height) {
            sum += Double(ptr[i])
        }
        let mean = sum / Double(width * height)
        
        // Calculate variance
        var sumSqDiff: Double = 0
        for i in 0..<(width * height) {
            let diff = Double(ptr[i]) - mean
            sumSqDiff += diff * diff
        }
        
        return sumSqDiff / Double(width * height)
    }
}

struct MaskAnalyzer {
    struct Point: Equatable {
        let x: Int
        let y: Int
    }
    
    static func analyze(mask: [Float], width: Int, height: Int) -> (lobulation: Float, circularity: Float, convexity: Float) {
        var points: [Point] = []
        var area: Float = 0
        
        // 1. Extract points and calculate area
        for y in 0..<height {
            for x in 0..<width {
                if mask[y * width + x] > 0.5 {
                    points.append(Point(x: x, y: y))
                    area += 1
                }
            }
        }
        
        guard area > 0 else { return (0, 0, 0) }
        
        // 2. Calculate Perimeter (Boundary pixels)
        // Simple approach: count pixels with at least one zero neighbor
        var perimeter: Float = 0
        for p in points {
            if isBoundary(p, width: width, height: height, mask: mask) {
                perimeter += 1
            }
        }
        
        // 3. Calculate Convex Hull
        let hull = convexHull(points)
        
        // 4. Calculate Convex Hull Perimeter
        var hullPerimeter: Float = 0
        if hull.count > 1 {
            for i in 0..<hull.count {
                let p1 = hull[i]
                let p2 = hull[(i + 1) % hull.count]
                let dist = sqrt(pow(Float(p1.x - p2.x), 2) + pow(Float(p1.y - p2.y), 2))
                hullPerimeter += dist
            }
        }
        
        // 5. Calculate Metrics
        // Circularity: 4 * pi * Area / Perimeter^2
        let circularity = perimeter > 0 ? (4 * .pi * area) / (perimeter * perimeter) : 0
        
        // Convexity: ConvexHullPerimeter / Perimeter
        // (Note: Standard definition is usually ConvexHullPerimeter / Perimeter, or Area / ConvexHullArea. 
        // Using Perimeter ratio here as it relates to edge irregularity/lobulation)
        let convexity = perimeter > 0 ? hullPerimeter / perimeter : 0
        
        // Lobulation Score: Inverse of convexity (or irregularity measure)
        // If convexity is 1.0 (perfectly convex), lobulation is 0.
        // If convexity is low (very irregular), lobulation is high.
        // However, convexity by perimeter ratio is usually <= 1.0.
        // Let's use (1 - convexity) * 100
        let lobulation = max(0, (1.0 - convexity) * 100)
        
        return (lobulation, circularity, convexity)
    }
    
    static func isBoundary(_ p: Point, width: Int, height: Int, mask: [Float]) -> Bool {
        let neighbors = [
            (0, 1), (0, -1), (1, 0), (-1, 0)
        ]
        
        for (dx, dy) in neighbors {
            let nx = p.x + dx
            let ny = p.y + dy
            
            if nx < 0 || nx >= width || ny < 0 || ny >= height {
                return true
            }
            if mask[ny * width + nx] <= 0.5 {
                return true
            }
        }
        return false
    }
    
    // Monotone Chain Algorithm
    static func convexHull(_ points: [Point]) -> [Point] {
        guard points.count > 2 else { return points }
        
        let sortedPoints = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        
        var upper: [Point] = []
        for p in sortedPoints {
            while upper.count >= 2 {
                let p1 = upper[upper.count - 2]
                let p2 = upper[upper.count - 1]
                if crossProduct(o: p1, a: p2, b: p) <= 0 {
                    upper.removeLast()
                } else {
                    break
                }
            }
            upper.append(p)
        }
        
        var lower: [Point] = []
        for p in sortedPoints.reversed() {
            while lower.count >= 2 {
                let p1 = lower[lower.count - 2]
                let p2 = lower[lower.count - 1]
                if crossProduct(o: p1, a: p2, b: p) <= 0 {
                    lower.removeLast()
                } else {
                    break
                }
            }
            lower.append(p)
        }
        
        return upper + lower.dropFirst().dropLast()
    }
    
    static func crossProduct(o: Point, a: Point, b: Point) -> Int {
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
}

struct AnalysisResult: Identifiable, Equatable {
    let id: UUID
    let patientId: String
    let patientName: String
    let timestamp: Date
    let diagnosis: String
    let confidence: Float
    let detections: [YOLODetection]
    let inferenceMode: String
    let lobulationScore: Float?
    let circularity: Float?
    let convexity: Float?
    let qualityWarnings: [String]
}

