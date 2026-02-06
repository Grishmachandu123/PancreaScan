//  FederatedLearningService.swift
//  Manages federated learning model updates and synchronization

import Foundation

class FederatedLearningService {
    static let shared = FederatedLearningService()
    
    private let userDefaults = UserDefaults.standard
    private let currentModelVersionKey = "current_model_version"
    private let lastSyncDateKey = "last_sync_date"
    private let autoSyncEnabledKey = "auto_sync_enabled"
    
    private init() {}
    
    var currentModelVersion: String {
        get { userDefaults.string(forKey: currentModelVersionKey) ?? "1.0.0" }
        set { userDefaults.set(newValue, forKey: currentModelVersionKey) }
    }
    
    var lastSyncDate: Date? {
        get { userDefaults.object(forKey: lastSyncDateKey) as? Date }
        set  { userDefaults.set(newValue, forKey: lastSyncDateKey) }
    }
    
    var autoSyncEnabled: Bool {
        get { userDefaults.bool(forKey: autoSyncEnabledKey) }
        set { userDefaults.set(newValue, forKey: autoSyncEnabledKey) }
    }
    
    // MARK: - Model Update
    
    func checkForUpdates(completion: @escaping (Result<ModelInfo?, Error>) -> Void) {
        NetworkService.shared.checkLatestModel { [weak self] result in
            switch result {
            case .success(let modelInfo):
                // Check if update available
                if modelInfo.version != self?.currentModelVersion {
                    completion(.success(modelInfo))
                } else {
                    completion(.success(nil))  // No update needed
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func downloadAndInstallUpdate(modelInfo: ModelInfo,
                                  progress: @escaping (Float) -> Void,
                                  completion: @escaping (Result<Bool, Error>) -> Void) {
        NetworkService.shared.downloadModel(from: modelInfo.downloadURL, progress: progress) { [weak self] result in
            switch result {
            case .success(let tempURL):
                // Move to app's document directory
                do {
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let modelURL = documentsURL.appendingPathComponent("pancreas.tflite")
                    
                    // Remove old model if exists
                    if FileManager.default.fileExists(atPath: modelURL.path) {
                        try FileManager.default.removeItem(at: modelURL)
                    }
                    
                    // Move new model
                    try FileManager.default.moveItem(at: tempURL, to: modelURL)
                    
                    // Update version
                    self?.currentModelVersion = modelInfo.version
                    self?.lastSyncDate = Date()
                    
                    // Reload TFLite model
                    TFLiteService.shared.loadModel()
                    
                    completion(.success(true))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Auto Sync
    
    func performAutoSync() {
        guard autoSyncEnabled else { return }
        
        // Check if enough time has passed since last sync (e.g., 24 hours)
        if let lastSync = lastSyncDate {
            let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceSync < 24 {
                return  // Too soon
            }
        }
        
        checkForUpdates { [weak self] result in
            switch result {
            case .success(let modelInfo):
                if let modelInfo = modelInfo {
                    print("📥 Auto-sync: New model version \(modelInfo.version) available")
                    self?.downloadAndInstallUpdate(modelInfo: modelInfo, progress: { _ in }) { result in
                        if case .success = result {
                            print("✅ Auto-sync: Model updated successfully")
                        }
                    }
                }
            case .failure(let error):
                print("❌ Auto-sync failed: \(error.localizedDescription)")
            }
        }
    }
}
