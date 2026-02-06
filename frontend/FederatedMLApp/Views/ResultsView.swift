//  ResultsView.swift
//  Display analysis results with bounding boxes

import SwiftUI
import UIKit

struct ResultsView: View {
    let result: AnalysisResult
    let originalImage: UIImage
    let patientName: String
    let patientId: String
    
    @Environment(\.dismiss) var dismiss
    @State private var annotatedImage: UIImage?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Adaptive sizing based on device and layout
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isLandscape: Bool {
        horizontalSizeClass == .regular
    }
    
    private var imageMaxHeight: CGFloat {
        // If stacking vertically (compact width), use smaller height
        if !isLandscape {
            return isIPad ? 350 : 250
        } else {
            // Side-by-side allows taller images
            return 500
        }
    }
    
    private var contentMaxWidth: CGFloat {
        isLandscape ? 1000 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        isIPad ? 30 : 16
    }

    var resultImages: some View {
        Group {
            VStack(spacing: 8) {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: imageMaxHeight)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                Text("Original CT Scan")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 8) {
                if let annotatedImage = annotatedImage {
                    Image(uiImage: annotatedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: imageMaxHeight)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: imageMaxHeight * 0.6)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                        )
                }
                Text("Detection Analysis")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: isIPad ? 25 : 20) {
                        headerSection
                        
                        // Quality Warnings
                        if !result.qualityWarnings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(result.qualityWarnings, id: \.self) { warning in
                                    HStack(alignment: .top) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(warning)
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, horizontalPadding)
                        }
                        
                        // Adaptive Layout for Images
                        Group {
                            if horizontalSizeClass == .compact {
                                VStack(spacing: 15) {
                                    resultImages
                                }
                            } else {
                                HStack(alignment: .top, spacing: 20) {
                                    resultImages
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .frame(maxWidth: contentMaxWidth)
                        
                        // Content container for iPad centering
                        VStack(spacing: isIPad ? 25 : 20) {
                            patientInfoCard
                            analysisResultsCard
                            finalObservationCard
                            feedbackCard
                            actionButtons
                        }
                        .frame(maxWidth: contentMaxWidth)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        shareReport()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            .sheet(isPresented: $showingShareSheet) {
                if let url = reportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onAppear {
                renderAnnotatedImage()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Analysis Results Card
    private var analysisResultsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Analysis Results")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Prediction:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(result.diagnosis == "ABNORMAL" ? "Abnormal (Pancreatitis/Edema)" : "Normal")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(result.diagnosis == "ABNORMAL" ? .red : .green)
                    .padding(8)
                    .background(result.diagnosis == "ABNORMAL" ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("Confidence:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int((result.confidence.isNaN ? 0 : result.confidence) * 100)).00%")
                    .font(isIPad ? .title3 : .body)
                    .fontWeight(.bold)
            }
            
            // Probabilities Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Probabilities:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Normal: \(result.diagnosis == "Normal" ? String(format: "%.2f", (result.confidence.isNaN ? 0 : result.confidence) * 100) : String(format: "%.2f", (1.0 - (result.confidence.isNaN ? 0 : result.confidence)) * 100))%")
                            .font(.caption)
                        Spacer()
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: isIPad ? 6 : 4)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            let normalWidth = geometry.size.width * CGFloat(result.diagnosis == "Normal" ? (result.confidence.isNaN ? 0 : result.confidence) : (1.0 - (result.confidence.isNaN ? 0 : result.confidence)))
                            let safeNormalWidth = normalWidth.isNaN ? 0 : normalWidth
                            
                            Rectangle()
                                .frame(width: safeNormalWidth, height: isIPad ? 6 : 4)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(height: isIPad ? 6 : 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Abnormal: \(result.diagnosis == "ABNORMAL" ? String(format: "%.2f", (result.confidence.isNaN ? 0 : result.confidence) * 100) : String(format: "%.2f", (1.0 - (result.confidence.isNaN ? 0 : result.confidence)) * 100))%")
                            .font(.caption)
                        Spacer()
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: isIPad ? 6 : 4)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            let abnormalWidth = geometry.size.width * CGFloat(result.diagnosis == "ABNORMAL" ? (result.confidence.isNaN ? 0 : result.confidence) : (1.0 - (result.confidence.isNaN ? 0 : result.confidence)))
                            let safeAbnormalWidth = abnormalWidth.isNaN ? 0 : abnormalWidth
                            
                            Rectangle()
                                .frame(width: safeAbnormalWidth, height: isIPad ? 6 : 4)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(height: isIPad ? 6 : 4)
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Final Observation Card
    private var finalObservationCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.pink)
                Text("Final Observation")
                    .font(.headline)
                    .foregroundColor(.pink)
            }
            
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.diagnosis == "ABNORMAL" ? "Abnormal Pancreas with Edema" : "Normal Pancreas Structure")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .foregroundColor(result.diagnosis == "ABNORMAL" ? .red : .green)
                    
                    Text("• Confidence: \(Int((result.confidence.isNaN ? 0 : result.confidence) * 100))%")
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                    
                    if result.diagnosis == "ABNORMAL" {
                        Text("• Analysis indicates signs consistent with pancreatitis or edema. The bounding box highlights areas of potential inflammation.")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        
                        Text("• Recommendation: Clinical correlation required. Consider follow-up imaging and laboratory tests (Amylase/Lipase).")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    } else {
                        Text("• No significant abnormalities detected in the analyzed region.")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Feedback Card
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                Text("Help Improve AI")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            Text("Is this diagnosis correct?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button(action: { submitFeedback(correct: true) }) {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("Yes, Correct")
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 16 : 12)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
                
                Button(action: { submitFeedback(correct: false) }) {
                    HStack {
                        Image(systemName: "hand.thumbsdown.fill")
                        Text("No, Incorrect")
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 16 : 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
            
            if let feedbackStatus = feedbackStatus {
                Text(feedbackStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { shareReport() }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share & Download Report")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(isIPad ? 16 : 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: { dismiss() }) {
                HStack {
                    Image(systemName: "house.fill")
                    Text("Return to Dashboard")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(isIPad ? 16 : 12)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, isIPad ? 30 : 20)
    }

    
    @State private var showingShareSheet = false
    @State private var reportURL: URL?
    @State private var feedbackStatus: String?
    
    private func submitFeedback(correct: Bool) {
        feedbackStatus = "Sending feedback..."
        
        // Create a correction based on user input
        // If correct, use the original prediction
        // If incorrect, we ideally want the user to correct it, but for now we'll just flag it
        // In a real app, we'd open an editor. Here we'll simulate a correction signal.
        
        let prediction = result.detections.first ?? YOLODetection(bbox: .zero, confidence: 0, classId: -1, className: "Unknown", mask: nil)
        
        // If incorrect, we might flip the class ID for the signal (simplified)
        let correction: YOLODetection?
        if correct {
            correction = prediction
        } else {
            // Flip class: 0->1, 1->0
            let newClassId = prediction.classId == 0 ? 1 : 0
            correction = YOLODetection(
                bbox: prediction.bbox,
                confidence: 1.0, // User is 100% confident
                classId: newClassId,
                className: newClassId == 0 ? "ABNORMAL" : "normal",
                mask: nil
            )
        }
        
        let signal = FLTrainingService.shared.generateTrainingSignal(
            for: originalImage,
            prediction: prediction,
            correction: correction
        )
        
        FLTrainingService.shared.uploadTrainingSignal(signal) { result in
            switch result {
            case .success:
                feedbackStatus = "✅ Thank you! Your feedback helps improve the model."
            case .failure(let error):
                feedbackStatus = "❌ Failed to send feedback: \(error.localizedDescription)"
            }
        }
    }
    
    private func shareReport() {
        // Generate PDF
        guard let data = PDFService.shared.generateReport(
            image: originalImage,
            segmentation: annotatedImage,
            result: result
        ) else { return }
        
        // Save to temporary file
        let fileName = "Medical_Report_\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            reportURL = url
            showingShareSheet = true
        } catch {
            print("Failed to save PDF: \(error)")
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.red)
            Text("Analysis Report")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
        }
        .padding()
    }
    
    private var patientInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Patient Information")
                .font(.headline)
                .foregroundColor(.blue)
            
            Divider()
            
            HStack {
                Text("Patient ID:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(patientId)
                    .fontWeight(.medium)
            }
            HStack {
                Text("Patient Name:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(patientName)
                    .fontWeight(.medium)
            }
            HStack {
                Text("Scan Date:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(result.timestamp.formatted(date: .complete, time: .omitted))
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    

    
    private func renderAnnotatedImage() {
        let imageSize = originalImage.size
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let fullAnnotatedImage = renderer.image { context in
            // Draw original image as background
            originalImage.draw(in: CGRect(origin: .zero, size: imageSize))
            
            let ctx = context.cgContext
            
            if result.detections.isEmpty {
                // Draw "No Abnormalities Detected" overlay
                ctx.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
                ctx.fill(CGRect(origin: .zero, size: imageSize))
                
                let text = "No Abnormalities Detected"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                    .foregroundColor: UIColor.white
                ]
                let string = NSAttributedString(string: text, attributes: attributes)
                let size = string.size()
                let rect = CGRect(
                    x: (imageSize.width - size.width) / 2,
                    y: (imageSize.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
                string.draw(in: rect)
            } else {
                // Draw bounding boxes only (no segmentation mask)
                for detection in result.detections {
                    // Skip invalid boxes (NaN check to prevent CoreGraphics errors)
                    let bbox = detection.bbox
                    if bbox.origin.x.isNaN || bbox.origin.y.isNaN || 
                       bbox.width.isNaN || bbox.height.isNaN ||
                       bbox.width <= 0 || bbox.height <= 0 {
                        print("⚠️ Skipping invalid bbox: \(bbox)")
                        continue
                    }
                    
                    // Set color based on class
                    let color: UIColor
                    if detection.classId == 0 { // ABNORMAL
                        color = UIColor.red
                    } else {
                        color = UIColor.green // Normal
                    }
                    
                    // Draw bounding box
                    let bboxRect = CGRect(
                        x: bbox.origin.x,
                        y: bbox.origin.y,
                        width: bbox.width,
                        height: bbox.height
                    )
                    ctx.setStrokeColor(color.cgColor)
                    ctx.setLineWidth(2.0)  // Match server.py line width
                    ctx.stroke(bboxRect)
                    
                    // Draw Label
                    let label = "\(detection.className) \(String(format: "%.1f", detection.confidence * 100))%"
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .left
                    
                    // Scale font size based on image size (like server.py)
                    let fontSize = max(12, min(24, imageSize.width * 0.03))
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    let string = NSAttributedString(string: " \(label) ", attributes: attributes)
                    let size = string.size()
                    
                    // Position label: above box if room, otherwise inside at top
                    let labelY: CGFloat
                    if bboxRect.origin.y >= size.height {
                        // Room above - draw above the box
                        labelY = bboxRect.origin.y - size.height
                    } else {
                        // No room above - draw inside at top of box
                        labelY = bboxRect.origin.y + 2
                    }
                    
                    let labelRect = CGRect(
                        x: bboxRect.origin.x,
                        y: labelY,
                        width: size.width,
                        height: size.height
                    )
                    
                    // Draw label background
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(labelRect)
                    
                    // Draw text
                    string.draw(in: labelRect)
                }
            }
        }
        
        // Use the full annotated image (no cropping)
        annotatedImage = fullAnnotatedImage
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let sampleImage = UIImage(systemName: "photo")!
    let sampleDetection = YOLODetection(
        bbox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
        confidence: 0.85,
        classId: 0,
        className: "ABNORMAL",
        mask: nil
    )
    let sampleResult = AnalysisResult(
        id: UUID(),
        patientId: "1234",
        patientName: "Hello",
        timestamp: Date(),
        diagnosis: "ABNORMAL",
        confidence: 1.0,
        detections: [sampleDetection],
        inferenceMode: "Offline",
        lobulationScore: 39.4,
        circularity: 0.850,
        convexity: 0.920,
        qualityWarnings: ["Low resolution image. Please upload a clearer scan."]
    )
    
    ResultsView(
        result: sampleResult,
        originalImage: sampleImage,
        patientName: "Hello",
        patientId: "1234"
    )
}
