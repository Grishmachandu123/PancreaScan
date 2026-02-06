import Foundation

class SyncService {
    static let shared = SyncService()
    
    private let serverURL = "http://172.25.81.70:8000" // Updated to current machine IP
    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.setValue(newValue, forKey: "auth_token") }
    }
    
    private init() {}
    
    // MARK: - Authentication
    
    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/login") else {
            completion(.failure(SyncError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                completion(.failure(SyncError.invalidResponse))
                return
            }
            
            self.authToken = token
            completion(.success(token))
        }.resume()
    }
    
    // MARK: -  Sync Predictions
    
    func syncPredictions(completion: @escaping (Result<Int, Error>) -> Void) {
        let unsyncedPredictions = SQLiteHelper.shared.getUnsyncedPredictions()
        
        guard !unsyncedPredictions.isEmpty else {
            completion(.success(0))
            return
        }
        
        print("📤 Syncing \(unsyncedPredictions.count) predictions...")
        
        var syncedCount = 0
        let group = DispatchGroup()
        
        for prediction in unsyncedPredictions {
            group.enter()
            
            // In production, send to server endpoint
            // For now, just mark as synced
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                SQLiteHelper.shared.markPredictionSynced(id: prediction.id)
                syncedCount += 1
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Synced \(syncedCount) predictions")
            completion(.success(syncedCount))
        }
    }
    
    // MARK: - Sync FL Updates
    
    func syncFLUpdates(completion: @escaping (Result<Int, Error>) -> Void) {
        let unsyncedUpdates = SQLiteHelper.shared.getUnsyncedFLUpdates()
        
        guard !unsyncedUpdates.isEmpty else {
            completion(.success(0))
            return
        }
        
        guard let token = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        print("📤 Syncing \(unsyncedUpdates.count) FL updates...")
        
        var syncedCount = 0
        let group = DispatchGroup()
        
        for flUpdate in unsyncedUpdates {
            group.enter()
            
            uploadFLUpdate(update: flUpdate.update, round: flUpdate.round, token: token) { result in
                switch result {
                case .success:
                    SQLiteHelper.shared.markFLUpdateSynced(id: flUpdate.id)
                    syncedCount += 1
                case .failure(let error):
                    print("❌ Failed to sync FL update \(flUpdate.id): \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Synced \(syncedCount) FL updates")
            completion(.success(syncedCount))
        }
    }
    
    private func uploadFLUpdate(update: Data, round: Int, token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/fl/upload") else {
            completion(.failure(SyncError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add update file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"update\"; filename=\"update.bin\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(update)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add round number
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"round\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(round)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(SyncError.invalidResponse))
            }
        }.resume()
    }
    
    // MARK: - Download Model
    
    func downloadLatestModel(completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/fl/latestModel") else {
            completion(.failure(SyncError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.downloadTask(with: request) { localURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let localURL = localURL else {
                completion(.failure(SyncError.invalidResponse))
                return
            }
            
            // Save model to documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsURL.appendingPathComponent("models").appendingPathComponent("model_latest.tflite")
            
            // Create models directory if needed
            try? FileManager.default.createDirectory(at: documentsURL.appendingPathComponent("models"),
                                                      withIntermediateDirectories: true)
            
            // Move downloaded file
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.moveItem(at: localURL, to: destinationURL)
            
            // Save model version
            let version = Int(Date().timeIntervalSince1970)
            SQLiteHelper.shared.saveModelVersion(version: version, modelPath: destinationURL.path)
            
            print("✅ Downloaded latest model: \(destinationURL.path)")
            completion(.success(destinationURL.path))
        }.resume()
    }
    
    // MARK: - Full Sync
    
    func syncAll(completion: @escaping (Result<(predictions: Int, flUpdates: Int), Error>) -> Void) {
        let group = DispatchGroup()
        
        var predictionsCount = 0
        var flUpdatesCount = 0
        var errors: [Error] = []
        
        // Sync predictions
        group.enter()
        syncPredictions { result in
            switch result {
            case .success(let count):
                predictionsCount = count
            case .failure(let error):
                errors.append(error)
            }
            group.leave()
        }
        
        // Sync FL updates
        group.enter()
        syncFLUpdates { result in
            switch result {
            case .success(let count):
                flUpdatesCount = count
            case .failure(let error):
                errors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if !errors.isEmpty {
                completion(.failure(errors[0]))
            } else {
                completion(.success((predictionsCount, flUpdatesCount)))
            }
        }
    }
}

// MARK: - Error Types

enum SyncError: Error {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "User not authenticated"
        }
    }
}
