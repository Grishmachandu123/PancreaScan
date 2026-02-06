//
//  PDFService.swift
//  FederatedMLApp
//
//  Created by FederatedMLApp on 11/25/24.
//

import UIKit
import PDFKit

class PDFService {
    static let shared = PDFService()
    
    private init() {}
    
    func generateReport(image: UIImage, segmentation: UIImage?, result: AnalysisResult) -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageWidth: CGFloat = 595.2 // A4 width
        let pageHeight: CGFloat = 841.8 // A4 height
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            // 1. Header
            drawHeader(pageRect: pageRect)
            
            // 2. Patient Info
            drawPatientInfo(pageRect: pageRect, result: result)
            
            // 3. Images (Original & Segmentation)
            drawImages(pageRect: pageRect, original: image, segmentation: segmentation)
            
            // 4. Diagnosis & Metrics
            drawDiagnosis(pageRect: pageRect, result: result)
            
            // 5. Footer
            drawFooter(pageRect: pageRect)
        }
        
        return data
    }
    
    private func drawHeader(pageRect: CGRect) {
        let title = "Medical Analysis Report"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: attributes)
        let titleRect = CGRect(
            x: (pageRect.width - titleSize.width) / 2,
            y: 50,
            width: titleSize.width,
            height: titleSize.height
        )
        
        title.draw(in: titleRect, withAttributes: attributes)
        
        // Subtitle
        let subtitle = "Federated Learning Analysis System"
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]
        
        let subSize = subtitle.size(withAttributes: subAttributes)
        let subRect = CGRect(
            x: (pageRect.width - subSize.width) / 2,
            y: titleRect.maxY + 5,
            width: subSize.width,
            height: subSize.height
        )
        
        subtitle.draw(in: subRect, withAttributes: subAttributes)
        
        // Divider
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 50, y: subRect.maxY + 20))
        path.addLine(to: CGPoint(x: pageRect.width - 50, y: subRect.maxY + 20))
        path.lineWidth = 1.0
        UIColor.lightGray.setStroke()
        path.stroke()
    }
    
    private func drawPatientInfo(pageRect: CGRect, result: AnalysisResult) {
        let startY: CGFloat = 130
        let x: CGFloat = 50
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        let info = [
            "Date: \(dateFormatter.string(from: Date()))",
            "Report ID: \(UUID().uuidString.prefix(8))"
        ]
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        for (index, text) in info.enumerated() {
            let rect = CGRect(x: x, y: startY + CGFloat(index * 20), width: 400, height: 20)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
    
    private func drawImages(pageRect: CGRect, original: UIImage, segmentation: UIImage?) {
        let y: CGFloat = 180
        let imageWidth: CGFloat = 200
        let imageHeight: CGFloat = 200
        let spacing: CGFloat = 40
        
        // Original Image
        let originalRect = CGRect(
            x: (pageRect.width - (imageWidth * 2 + spacing)) / 2,
            y: y,
            width: imageWidth,
            height: imageHeight
        )
        original.draw(in: originalRect)
        
        drawLabel("Original Scan", rect: originalRect)
        
        // Segmentation Image
        if let segImage = segmentation {
            let segRect = CGRect(
                x: originalRect.maxX + spacing,
                y: y,
                width: imageWidth,
                height: imageHeight
            )
            segImage.draw(in: segRect)
            drawLabel("AI Segmentation", rect: segRect)
        }
    }
    
    private func drawLabel(_ text: String, rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let labelRect = CGRect(x: rect.minX, y: rect.maxY + 5, width: rect.width, height: 20)
        text.draw(in: labelRect, withAttributes: attributes)
    }
    
    private func drawDiagnosis(pageRect: CGRect, result: AnalysisResult) {
        let startY: CGFloat = 430
        let x: CGFloat = 50
        let width = pageRect.width - 100
        
        // Diagnosis Box
        let boxRect = CGRect(x: x, y: startY, width: width, height: 100)
        let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 10)
        
        if result.diagnosis == "ABNORMAL" {
            UIColor.red.withAlphaComponent(0.1).setFill()
            UIColor.red.setStroke()
        } else {
            UIColor.green.withAlphaComponent(0.1).setFill()
            UIColor.green.setStroke()
        }
        
        path.fill()
        path.lineWidth = 1
        path.stroke()
        
        // Diagnosis Text
        let diagnosisTitle = "Diagnosis: \(result.diagnosis)"
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: result.diagnosis == "ABNORMAL" ? UIColor.red : UIColor.green
        ]
        
        diagnosisTitle.draw(at: CGPoint(x: x + 20, y: startY + 20), withAttributes: titleAttr)
        
        // Confidence
        let confidenceText = "Confidence: \(Int(result.confidence * 100))%"
        let confAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        confidenceText.draw(at: CGPoint(x: x + 20, y: startY + 55), withAttributes: confAttr)
        
        // Metrics Section
        let metricsY = boxRect.maxY + 30
        
        let metricsTitle = "Detailed Analysis Metrics"
        let metricTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        metricsTitle.draw(at: CGPoint(x: x, y: metricsY), withAttributes: metricTitleAttr)
        
        // Metrics List
        var currentY = metricsY + 30
        
        let metrics = [
            "Lobulation Score: \(String(format: "%.2f", result.lobulationScore ?? 0.0))",
            "Circularity: \(String(format: "%.2f", result.circularity ?? 0.0))",
            "Convexity: \(String(format: "%.2f", result.convexity ?? 0.0))"
        ]
        
        let metricAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        
        for metric in metrics {
            metric.draw(at: CGPoint(x: x + 20, y: currentY), withAttributes: metricAttr)
            currentY += 25
        }
        
        // Quality Warnings
        if !result.qualityWarnings.isEmpty {
            currentY += 20
            let warningTitle = "Quality Warnings:"
            let warningTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.orange
            ]
            warningTitle.draw(at: CGPoint(x: x, y: currentY), withAttributes: warningTitleAttr)
            
            currentY += 20
            let warningAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            
            for warning in result.qualityWarnings {
                ("• " + warning).draw(at: CGPoint(x: x + 20, y: currentY), withAttributes: warningAttr)
                currentY += 20
            }
        }
    }
    
    private func drawFooter(pageRect: CGRect) {
        let text = "Generated by Septalyze App • Not for clinical diagnosis"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: UIColor.lightGray,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let rect = CGRect(x: 0, y: pageRect.height - 40, width: pageRect.width, height: 20)
        text.draw(in: rect, withAttributes: attributes)
    }
}
