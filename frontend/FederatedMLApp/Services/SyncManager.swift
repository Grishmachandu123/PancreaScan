
import Foundation
import Network
import UIKit
import Combine

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    private let monitor = NWPathMonitor()
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("\n==============================================")
                print("🌐 NETWORK STATUS: ONLINE (Connected)")
                print("==============================================\n")
                print("🔄 Triggering Auto-Sync...")
                DispatchQueue.main.async {
                    self?.syncPendingData()
                }
            } else {
                print("\n==============================================")
                print("🚫 NETWORK STATUS: OFFLINE (No Connection)")
                print("   Data will be saved locally and synced later.")
                print("==============================================\n")
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    func syncPendingData() {
        syncPendingScans()
        syncPendingFLUpdates()
    }
    
    // ... (syncPendingScans implementation) ...
    
    private func syncPendingFLUpdates() {
        // We need to update SQLiteHelper.getUnsyncedFLUpdates to return userEmail too if we want to be precise, 
        // but for now let's just process them.
        let unsynced = SQLiteHelper.shared.getUnsyncedFLUpdates()
        guard !unsynced.isEmpty else { return }
        
        print("🔄 Found \(unsynced.count) pending FL updates to sync...")
        
        for record in unsynced {
            if let signal = try? JSONDecoder().decode(TrainingSignal.self, from: record.update) {
                FLTrainingService.shared.uploadTrainingSignal(signal) { result in
                    switch result {
                    case .success(let success):
                        if success {
                            SQLiteHelper.shared.markFLUpdateSynced(id: record.id)
                            print("✅ Synced FL update \(record.id)")
                        }
                    case .failure(let error):
                        print("❌ FL Sync failed for \(record.id): \(error)")
                    }
                }
            } else {
                print("❌ Failed to decode FL update \(record.id)")
            }
        }
    }
    
    private func syncPendingScans() {
        let unsynced = SQLiteHelper.shared.getUnsyncedPredictions()
        print("🔍 SyncManager: Checking for unsynced scans. Found: \(unsynced.count)")
        
        guard !unsynced.isEmpty else { return }
        
        for record in unsynced {
            print("📤 SyncManager: Attempting to sync record ID: \(record.id)")
            
            // Reconstruct UIImage
            // Reconstruct UIImage with Path Recovery
            var image: UIImage?
            var currentPath = record.imagePath
            
            if FileManager.default.fileExists(atPath: currentPath) {
                image = UIImage(contentsOfFile: currentPath)
            } else {
                // Try recovery from current Documents directory
                print("⚠️ SyncManager: File not found at \(currentPath). Attempting recovery from current Documents directory...")
                
                let filename = (currentPath as NSString).lastPathComponent
                if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                     let recoveredPath = documentsURL.appendingPathComponent("scans").appendingPathComponent(filename).path
                     
                     if FileManager.default.fileExists(atPath: recoveredPath) {
                         print("✅ SyncManager: Recovered file at \(recoveredPath)")
                         image = UIImage(contentsOfFile: recoveredPath)
                     } else {
                         print("❌ SyncManager: Recovery failed. File not found at \(recoveredPath)")
                     }
                }
            }
            
            guard let img = image else {
                print("❌ SyncManager: Skipped sync for \(record.id): Image file missing.")
                continue
            }
             
            // Debug: Check email validity
            print("   - User Email: \(record.userEmail)")
            

            // Determine email to use
            var emailToUse = record.userEmail
            if emailToUse.isEmpty {
                print("⚠️ SyncManager: Record \(record.id) has no userEmail. Proceeding with current session email.")
                emailToUse = UserDefaults.standard.string(forKey: "user_email") ?? ""
            }
            
            guard !emailToUse.isEmpty else {
                 print("❌ SyncManager: Skipping record \(record.id). No user email available.")
                 continue
            }
            
            NetworkService.shared.syncScan(
                image: img,
                result: record.result,
                confidence: record.confidence,
                patientId: record.patientId,
                patientName: record.patientName,
                timestamp: record.timestamp,
                explicitEmail: emailToUse
            ) { result in
                switch result {
                case .success(let success):
                    if success {
                        SQLiteHelper.shared.markPredictionSynced(id: record.id)
                        print("✅ SyncManager: Successfully synced record \(record.id)")
                    } else {
                        print("⚠️ SyncManager: Server returned success=false for record \(record.id)")
                    }
                case .failure(let error):
                    print("❌ SyncManager: Network sync failed for \(record.id). Error: \(error)")
                }
            }
        }
    }
}
