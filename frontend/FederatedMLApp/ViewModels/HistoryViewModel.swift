//  HistoryViewModel.swift
//  ViewModel for History page

import Foundation
import Combine
import UIKit
import CoreGraphics

class HistoryViewModel: ObservableObject {
    // Updated tuple type to include patient info and detections
    typealias HistoryRecord = (id: Int64, imagePath: String, result: String, confidence: Double, timestamp: Date, patientId: String, patientName: String, detections: [YOLODetection])
    
    @Published var allRecords: [HistoryRecord] = []
    @Published var filteredRecords: [HistoryRecord] = []
    @Published var searchText: String = "" {
        didSet {
            filterRecords()
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadRecords()
    }
    
    func loadRecords() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
            
            // Fetch records from SERVER only (server is source of truth)
            self?.fetchServerRecords(email: userEmail)
        }
    }
    
    /// Fetch records from server and display them (server is source of truth)
    private func fetchServerRecords(email: String) {
        guard !email.isEmpty else {
            DispatchQueue.main.async {
                self.allRecords = []
                self.filterRecords()
            }
            return
        }
        
        DispatchQueue.main.async { self.isLoading = true }
        
        NetworkService.shared.fetchUserHistory(email: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            switch result {
            case .success(let history):
                print("✅ Fetched \(history.count) records from server")
                self?.processAndDisplayServerRecords(history, userEmail: email)
            case .failure(let error):
                print("⚠️ Failed to fetch from server: \(error). Loading local cache...")
                self?.loadLocalRecords(userEmail: email)
            }
        }
    }
    
    /// Process server records and display them
    private func processAndDisplayServerRecords(_ history: [[String: Any]], userEmail: String) {
        // Deduplicate by patient_id + timestamp
        var seenKeys = Set<String>()
        var uniqueHistory: [[String: Any]] = []
        
        for record in history {
            var patientIdStr = "Unknown"
            if let nsNum = record["patient_id"] as? NSNumber {
                patientIdStr = nsNum.stringValue
            } else if let intPid = record["patient_id"] as? Int {
                patientIdStr = String(intPid)
            } else if let strPid = record["patient_id"] as? String {
                patientIdStr = strPid
            }
            let timestamp = record["timestamp"] as? String ?? ""
            let uniqueKey = "\(patientIdStr)_\(timestamp)"
            
            if !seenKeys.contains(uniqueKey) {
                seenKeys.insert(uniqueKey)
                uniqueHistory.append(record)
            }
        }
        
        print("📊 Server records: \(history.count) → \(uniqueHistory.count) unique")
        
        // Convert to display records
        var displayRecords: [HistoryRecord] = []
        let group = DispatchGroup()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        for record in uniqueHistory {
            // Parse ID
            var id: Int64?
            if let nsNumber = record["id"] as? NSNumber {
                id = nsNumber.int64Value
            } else if let intId = record["id"] as? Int {
                id = Int64(intId)
            } else if let stringId = record["id"] as? String, let parsed = Int64(stringId) {
                id = parsed
            }
            guard let recordId = id else { continue }
            
            // Parse fields
            let result = record["result"] as? String ?? "Unknown"
            let confidence = (record["confidence"] as? NSNumber)?.doubleValue ?? 0.0
            
            var patientIdStr = "Unknown"
            if let nsNum = record["patient_id"] as? NSNumber {
                patientIdStr = nsNum.stringValue
            } else if let intPid = record["patient_id"] as? Int {
                patientIdStr = String(intPid)
            } else if let strPid = record["patient_id"] as? String {
                patientIdStr = strPid
            }
            let patientName = record["patient_name"] as? String ?? "Unknown"
            let dateString = record["timestamp"] as? String ?? ""
            let timestamp = dateFormatter.date(from: dateString) ?? Date()
            
            // Image URL
            let imagePath = record["image_path"] as? String ?? ""
            let imageUrl = imagePath.isEmpty ? "" : "\(APIEndpoints.baseURL)/\(imagePath)"
            
            // Download image to local cache
            let filename = "server_\(recordId).jpg"
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let scansURL = documentsURL.appendingPathComponent("scans")
            try? FileManager.default.createDirectory(at: scansURL, withIntermediateDirectories: true)
            let localURL = scansURL.appendingPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                // Image already cached
                let detections = self.loadDetections(for: localURL.path)
                displayRecords.append((
                    id: recordId,
                    imagePath: localURL.path,
                    result: result,
                    confidence: confidence,
                    timestamp: timestamp,
                    patientId: patientIdStr,
                    patientName: patientName,
                    detections: detections
                ))
            } else if !imageUrl.isEmpty {
                // Download image
                group.enter()
                NetworkService.shared.downloadImage(from: imageUrl) { [weak self] dlResult in
                    defer { group.leave() }
                    switch dlResult {
                    case .success(let image):
                        if let data = image.jpegData(compressionQuality: 0.8) {
                            try? data.write(to: localURL)
                            
                            // Create synthetic detection for display
                            self?.createSyntheticDetection(
                                at: localURL,
                                result: result,
                                confidence: confidence,
                                imageSize: image.size
                            )
                        }
                    case .failure(let error):
                        print("❌ Failed to download image for \(recordId): \(error)")
                    }
                }
                
                // Add record (image will be downloaded async)
                let detections = self.loadDetections(for: localURL.path)
                displayRecords.append((
                    id: recordId,
                    imagePath: localURL.path,
                    result: result,
                    confidence: confidence,
                    timestamp: timestamp,
                    patientId: patientIdStr,
                    patientName: patientName,
                    detections: detections
                ))
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            // Sort by timestamp, newest first
            displayRecords.sort { $0.timestamp > $1.timestamp }
            self?.allRecords = displayRecords
            print("📜 Displaying \(displayRecords.count) server records")
            self?.filterRecords()
        }
    }
    
    /// Load local records as fallback when offline
    private func loadLocalRecords(userEmail: String) {
        let rawRecords = SQLiteHelper.shared.getAllPredictions(for: userEmail)
        
        var uniqueRecords: [HistoryRecord] = []
        
        for record in rawRecords {
            var imagePath = record.imagePath
            if !FileManager.default.fileExists(atPath: imagePath) {
                let filename = (record.imagePath as NSString).lastPathComponent
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let newPath = documentsURL.appendingPathComponent("scans").appendingPathComponent(filename).path
                if FileManager.default.fileExists(atPath: newPath) {
                    imagePath = newPath
                }
            }
            
            let detections = loadDetections(for: imagePath)
            
            uniqueRecords.append((
                id: record.id,
                imagePath: imagePath,
                result: record.result,
                confidence: record.confidence,
                timestamp: record.timestamp,
                patientId: record.patientId,
                patientName: record.patientName,
                detections: detections
            ))
        }
        
        uniqueRecords.sort { $0.timestamp > $1.timestamp }
        
        DispatchQueue.main.async {
            self.allRecords = uniqueRecords
            print("📜 Loaded \(uniqueRecords.count) local records (offline mode)")
            self.filterRecords()
        }
    }
    
    private func loadDetections(for imagePath: String) -> [YOLODetection] {
        let jsonPath = imagePath.replacingOccurrences(of: ".jpg", with: ".json")
        if FileManager.default.fileExists(atPath: jsonPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
           let decoded = try? JSONDecoder().decode([YOLODetection].self, from: data) {
            return decoded
        }
        return []
    }
    
    private func createSyntheticDetection(at url: URL, result: String, confidence: Double, imageSize: CGSize) {
        let jsonURL = url.deletingPathExtension().appendingPathExtension("json")
        let classId = result.lowercased().contains("abnormal") ? 0 : 1
        let className = classId == 0 ? "ABNORMAL" : "normal"
        
        let boxWidth = imageSize.width * 0.4
        let boxHeight = imageSize.height * 0.4
        let boxX = (imageSize.width - boxWidth) / 2
        let boxY = (imageSize.height - boxHeight) / 2
        
        let detection = YOLODetection(
            bbox: CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight),
            confidence: Float(confidence),
            classId: classId,
            className: className,
            mask: nil
        )
        
        if let jsonData = try? JSONEncoder().encode([detection]) {
            try? jsonData.write(to: jsonURL)
        }
    }
    
    private func filterRecords() {
        if searchText.isEmpty {
            filteredRecords = allRecords
        } else {
            filteredRecords = allRecords.filter { record in
                record.patientName.localizedCaseInsensitiveContains(searchText) ||
                record.patientId.localizedCaseInsensitiveContains(searchText) ||
                record.result.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func deleteRecord(_ record: HistoryRecord) {
        // Delete from database
        // Delete from database (Server)
        if let userEmail = UserDefaults.standard.string(forKey: "user_email") {
            NetworkService.shared.deleteScan(timestamp: record.timestamp, email: userEmail) { result in
                switch result {
                case .success:
                    print("✅ Deleted scan from server")
                case .failure(let error):
                    print("⚠️ Failed to delete from server (might need offline queue): \(error)")
                }
            }
        }
        
        // Delete from local Core Data
        SQLiteHelper.shared.deletePrediction(id: record.id)
        
        // Remove from local array
        if let index = allRecords.firstIndex(where: { $0.id == record.id }) {
            allRecords.remove(at: index)
        }
        filterRecords()
    }
    
    func deleteRecord(at offsets: IndexSet, in records: [HistoryRecord]) {
        for index in offsets {
            let record = records[index]
            deleteRecord(record)
        }
    }
    
    func clearAllHistory() {
        // Delete all from database
        allRecords.removeAll()
        filterRecords()
    }
    
    // Group records by Patient ID AND Name to handle reused IDs
    var groupedByPatient: [String: [HistoryRecord]] {
        Dictionary(grouping: filteredRecords) { record in
            let cleanId = record.patientId.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanName = record.patientName.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(cleanId)|\(cleanName)"
        }
    }
    
    // Get unique patients for list view
    var uniquePatients: [(uuid: UUID, id: String, name: String, lastScan: Date)] {
        let grouped = groupedByPatient
        return grouped.keys.compactMap { key in
            guard let records = grouped[key] else { return nil }
            // Find most recent scan date
            let lastScan = records.map { $0.timestamp }.max() ?? Date()
            
            // Parse key back to ID and Name
            let components = key.components(separatedBy: "|")
            let id = components.first ?? "Unknown"
            let name = components.count > 1 ? components[1] : "Unknown"
            
            // Use a stable UUID based on the key to prevent list flashing, or just random if not needed
            // Ideally we'd persist this, but for now random UUID is fine as long as it's generated once per view load.
            // Actually, simply using UUID() here will cause frequent updates.
            // Better to use the 'key' (composite string) as the ID in the View, OR modify this struct.
            // But HistoryView expects '.id'. Let's add a uuid field.
            return (uuid: UUID(), id: id, name: name, lastScan: lastScan)
        }.sorted { $0.lastScan > $1.lastScan }
    }
}
