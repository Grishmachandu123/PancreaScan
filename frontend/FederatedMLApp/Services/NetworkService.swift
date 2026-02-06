//  NetworkService.swift
//  Network service for online inference and model updates

import Foundation
import UIKit
import Network


struct APIEndpoints {
    static let baseURL = "http://14.139.187.229:8081/oct/pancreas" // PHP Server
    static let auth = "\(baseURL)/auth.php"
    static let sync = "\(baseURL)/sync.php"
    static let fl = "\(baseURL)/fl.php"
}

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - Auth & Sync
    
    func login(email: String, password: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        postRequest(url: APIEndpoints.auth, params: ["action": "login", "email": email, "password": password], completion: completion)
    }
    
    func signup(name: String, email: String, password: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        postRequest(url: APIEndpoints.auth, params: ["action": "signup", "name": name, "email": email, "password": password], completion: completion)
    }
    
    func verifyOTP(email: String, otp: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        postRequest(url: APIEndpoints.auth, params: ["action": "verify_otp", "email": email, "otp": otp], completion: completion)
    }
    
    func requestPasswordReset(email: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        postRequest(url: APIEndpoints.auth, params: ["action": "request_password_reset", "email": email], completion: completion)
    }
    
    func resetPassword(email: String, otp: String, newPassword: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        postRequest(url: APIEndpoints.auth, params: ["action": "reset_password", "email": email, "otp": otp, "new_password": newPassword], completion: completion)
    }
    
    func syncScan(image: UIImage, result: String, confidence: Double, patientId: String, patientName: String, timestamp: Date? = nil, explicitEmail: String? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            completion(.failure(NetworkError.imageConversionFailed))
            return
        }
        
        // Use explicit email (for background sync) or current session email
        guard let userEmail = explicitEmail ?? UserDefaults.standard.string(forKey: "user_email") else {
            print("❌ Sync Error: No 'user_email' provided or found in UserDefaults.")
            completion(.failure(NetworkError.noData)) // No user logged in
            return
        }
        
        let params: [String: Any] = [
            "action": "upload_scan",
            "user_email": userEmail,
            "image": imageData,
            "result": result,
            "confidence": confidence,
            "patient_id": patientId,
            "patient_name": patientName,
            "timestamp": dateFormatter.string(from: timestamp ?? Date())
        ]
        
        postRequest(url: APIEndpoints.sync, params: params) { result in
            switch result {
            case .success(let json):
                if let status = json["status"] as? String, status == "success" {
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func postRequest(url: String, params: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Form Data
        // Form Data
        var bodyDataString = ""
        for (key, value) in params {
            let keyString = String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let valueString = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            bodyDataString += "\(keyString)=\(valueString)&"
        }
        // Remove trailing ampersand
        if !bodyDataString.isEmpty {
            bodyDataString.removeLast()
        }
        
        request.httpBody = bodyDataString.data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                print("❌ Network Request Failed for URL: \(url)")
                print("   Error Code: \(nsError.code)")
                print("   Description: \(nsError.localizedDescription)")
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                     print("   Underlying Error: \(underlying)")
                }
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                print("❌ No data received for URL: \(url)")
                DispatchQueue.main.async { completion(.failure(NetworkError.noData)) }
                return
            }
            
            // Allow debugging raw response
            if let rawString = String(data: data, encoding: .utf8) {
                print("🌐 Server Response for \(url): \(rawString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    DispatchQueue.main.async { completion(.success(json)) }
                } else {
                    print("❌ JSON Parsing failed (Data is not dictionary) for URL: \(url)")
                    DispatchQueue.main.async { completion(.failure(NetworkError.noData)) }
                }
            } catch {
                print("❌ JSON Parsing Error: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    // MARK: - Model Management
    
    func checkLatestModel(completion: @escaping (Result<ModelInfo, Error>) -> Void) {
        postRequest(url: APIEndpoints.fl, params: ["action": "get_global_model"]) { result in
            switch result {
            case .success(let json):
                guard let status = json["status"] as? String, status == "success",
                      let version = json["version"] as? String,
                      let url = json["download_url"] as? String else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                // Map to ModelInfo (filling missing fields with defaults since simple PHP script doesn't send them)
                let modelInfo = ModelInfo(
                    version: version,
                    downloadURL: url,
                    checksum: "MD5_PLACEHOLDER",
                    sizeBytes: 0,
                    releaseDate: nil
                )
                completion(.success(modelInfo))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func downloadModel(from url: String, progress: @escaping (Float) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let downloadURL = URL(string: url) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let session = URLSession(configuration: .default)
        let task = session.downloadTask(with: downloadURL) { localURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let localURL = localURL else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.downloadFailed))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(localURL))
            }
        }
        
        task.resume()
    }
    func clearHistory(email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let params = [
            "action": "clear_history",
            "user_email": email
        ]
        postRequest(url: APIEndpoints.sync, params: params) { result in
            switch result {
            case .success(let json):
                if let status = json["status"] as? String, status == "success" {
                    completion(.success(true))
                } else {
                    completion(.failure(NetworkError.serverError("Deletion failed")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func deleteAccount(email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let params = [
            "action": "delete_account",
            "email": email
        ]
        postRequest(url: APIEndpoints.auth, params: params) { result in
            switch result {
            case .success(let json):
                if let status = json["status"] as? String, status == "success" {
                    completion(.success(true))
                } else {
                    completion(.failure(NetworkError.serverError("Deletion failed")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    func deleteScan(timestamp: Date, email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let params = [
            "action": "delete_scan",
            "user_email": email,
            "timestamp": dateFormatter.string(from: timestamp)
        ]
        postRequest(url: APIEndpoints.sync, params: params) { result in
            switch result {
            case .success(let json):
                if let status = json["status"] as? String, status == "success" {
                    completion(.success(true))
                } else {
                    completion(.failure(NetworkError.serverError("Scan deletion failed")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchUserHistory(email: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let params = [
            "action": "get_history",
            "user_email": email
        ]
        postRequest(url: APIEndpoints.sync, params: params) { result in
            switch result {
            case .success(let json):
                // Log the JSON to debug what the server is actually returning
                print("DEBUG: History Response JSON: \(json)")
                
                if let status = json["status"] as? String, status == "success" {
                    if let history = json["history"] as? [[String: Any]] {
                        completion(.success(history))
                    } else if json["history"] == nil {
                        // Handle case where history might be missing if empty
                         print("DEBUG: 'history' key is missing, assuming empty list.")
                        completion(.success([]))
                    } else {
                         // Failed to cast
                         print("DEBUG: 'history' key exists but is not [[String:Any]]. Value: \(json["history"] ?? "nil")")
                        completion(.failure(NetworkError.parsingError("Invalid history format")))
                    }
                } else {
                    let msg = json["message"] as? String ?? "Unknown server error"
                    completion(.failure(NetworkError.serverError(msg)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func downloadImage(from urlString: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(.failure(NetworkError.downloadFailed)) }
                return
            }
            
            DispatchQueue.main.async { completion(.success(image)) }
        }.resume()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Align effectively with server if needed
        return formatter
    }
}

// MARK: - Response Models

struct PredictionResponse: Codable {
    let predictions: [PredictionData]
    let modelVersion: String?
}

struct PredictionData: Codable {
    let bbox: [Float]
    let confidence: Float
    let classId: Int
    let className: String
}

struct ModelInfo: Codable {
    let version: String
    let downloadURL: String
    let checksum: String
    let sizeBytes: Int
    let releaseDate: String?
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case imageConversionFailed
    case downloadFailed
    case serverError(String)
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .noData:
            return "No data received from server"
        case .imageConversionFailed:
            return "Failed to convert image"
        case .downloadFailed:
            return "Model download failed"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .parsingError(let details):
            return "Parsing Error: \(details)"
        }
    }
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected: Bool = false
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                print("🌐 Network Status Changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
            }
        }
        monitor.start(queue: queue)
    }
}

