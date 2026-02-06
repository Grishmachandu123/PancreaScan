//
//  DashboardViewModel.swift
//  FederatedMLApp
//
//  Created for Dashboard Stats
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var totalScans: Int = 0
    @Published var normalScans: Int = 0
    @Published var abnormalScans: Int = 0
    @Published var isLoading: Bool = false
    
    init() {
        loadStats()
    }
    
    func loadStats() {
        let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
        guard !userEmail.isEmpty else { return }
        
        isLoading = true
        
        // Fetch stats from server (source of truth)
        NetworkService.shared.fetchUserHistory(email: userEmail) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let history):
                    // Calculate stats from server data
                    self?.calculateStats(from: history)
                case .failure(_):
                    // Fallback to local stats if offline
                    self?.loadLocalStats(userEmail: userEmail)
                }
            }
        }
    }
    
    private func calculateStats(from history: [[String: Any]]) {
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
        
        var normal = 0
        var abnormal = 0
        
        for record in uniqueHistory {
            if let result = record["result"] as? String {
                if result.lowercased().contains("abnormal") {
                    abnormal += 1
                } else {
                    normal += 1
                }
            }
        }
        
        totalScans = uniqueHistory.count
        normalScans = normal
        abnormalScans = abnormal
        
        print("📊 Dashboard stats from server: Total=\(totalScans), Normal=\(normalScans), Abnormal=\(abnormalScans)")
    }
    
    private func loadLocalStats(userEmail: String) {
        let stats = SQLiteHelper.shared.getStats(for: userEmail)
        totalScans = stats.total
        normalScans = stats.normal
        abnormalScans = stats.abnormal
        print("📊 Dashboard stats from local (offline): Total=\(totalScans), Normal=\(normalScans), Abnormal=\(abnormalScans)")
    }
}
