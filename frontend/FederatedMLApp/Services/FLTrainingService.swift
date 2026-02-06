//  FLTrainingService.swift
//  Service for handling Federated Learning training signals and uploads

import Foundation
import UIKit

struct TrainingSignal: Codable {
    let imageId: String
    let originalPrediction: [Float] // [x, y, w, h, confidence, classId]
    let userCorrection: [Float]     // [x, y, w, h, confidence, classId]
    let timestamp: TimeInterval
    let deviceId: String
}

class FLTrainingService {
    static let shared = FLTrainingService()
    
    private init() {}
    
    // MARK: - Training Signal Generation
    
    func generateTrainingSignal(for image: UIImage, 
                              prediction: YOLODetection, 
                              correction: YOLODetection?) -> TrainingSignal {
        
        let predArray: [Float] = [
            Float(prediction.bbox.origin.x),
            Float(prediction.bbox.origin.y),
            Float(prediction.bbox.size.width),
            Float(prediction.bbox.size.height),
            prediction.confidence,
            Float(prediction.classId)
        ]
        
        let correctArray: [Float]
        if let correction = correction {
            correctArray = [
                Float(correction.bbox.origin.x),
                Float(correction.bbox.origin.y),
                Float(correction.bbox.size.width),
                Float(correction.bbox.size.height),
                correction.confidence,
                Float(correction.classId)
            ]
        } else {
            // If no correction provided, assume prediction was correct (reinforcement)
            correctArray = predArray
        }
        
        return TrainingSignal(
            imageId: UUID().uuidString,
            originalPrediction: predArray,
            userCorrection: correctArray,
            timestamp: Date().timeIntervalSince1970,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
    }
    
    // MARK: - Upload
    
    func uploadTrainingSignal(_ signal: TrainingSignal, completion: @escaping (Result<Bool, Error>) -> Void) {
        // Encode signal to JSON string
        guard let jsonData = try? JSONEncoder().encode(signal),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(NetworkError.imageConversionFailed)) // Reusing error
            return
        }
        
        let params: [String: Any] = [
            "action": "upload_gradients",
            "client_id": signal.deviceId,
            "gradients": jsonString
        ]
        
        // Use standard postRequest from NetworkService helper if accessible, or replicate it
        // Since NetworkService.postRequest is private, we'll implement the request manually here matching its style
        
        guard let url = URL(string: APIEndpoints.fl) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Form Data Construction
        var body = Data()
        for (key, value) in params {
            body.append("\(key)=\(value)&".data(using: .utf8)!)
        }
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.noData)) }
                return
            }
            
            // Debug output
            if let raw = String(data: data, encoding: .utf8) {
                print("FL Upload Response: \(raw)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let status = json["status"] as? String, status == "success" {
                    DispatchQueue.main.async { completion(.success(true)) }
                } else {
                    self.saveLocally(signal) // Save on server error response
                    DispatchQueue.main.async { completion(.failure(NetworkError.noData)) }
                }
            } catch {
                self.saveLocally(signal) // Save on parsing error
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    private func saveLocally(_ signal: TrainingSignal) {
        guard let data = try? JSONEncoder().encode(signal) else { return }
        // Using 'round' 0 for now as we don't track rounds deeply on client yet
        let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? "unknown"
        // Insert with userEmail (Need to update SQLiteHelper insertFLUpdate signature first? Yes.)
        // Actually I updated the schema but not the helper method for FLUpdates yet.
        // I need to update SQLiteHelper.insertFLUpdate to accept userEmail.
        _ = SQLiteHelper.shared.insertFLUpdate(update: data, round: 0, userEmail: userEmail)
        print("⚠️ Saved FL update locally for later sync")
    }
}
