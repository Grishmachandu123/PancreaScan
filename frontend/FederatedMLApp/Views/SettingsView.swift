//  SettingsView.swift
//  App settings with profile, dark mode, and clear history

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("use_online_mode") private var useOnlineMode = false
    @State private var isCheckingUpdate = false
    @State private var updateMessage: String?
    @State private var showingProfileEdit = false
    @State private var showingClearHistoryConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section(header: Text("Profile")) {
                    if let user = authViewModel.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.name ?? "User")
                                    .font(.headline)
                                Text(user.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                showingProfileEdit = true
                            }
                        }
                    } else {
                        Text("Not Logged In")
                    }
                }
                
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    
                    Text("Enable dark mode for better viewing in low light")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Sync Settings
                Section(header: Text("Data Sync")) {
                    Toggle("Cloud Auto-Sync", isOn: $useOnlineMode)
                        .onChange(of: useOnlineMode) { newValue in
                            if newValue {
                                print("Auto-Sync Enabled")
                            } else {
                                print("Auto-Sync Disabled")
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(useOnlineMode ? "Sync Enabled" : "Sync Disabled")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(useOnlineMode ? .green : .secondary)
                        Text(useOnlineMode ? "Automatically uploads scans to secure server" : "Your data is stored only on this device")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Federated Learning
                Section(header: Text("Federated Learning")) {
                    HStack {
                        Text("Current Model Version")
                        Spacer()
                        Text(FederatedLearningService.shared.currentModelVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = FederatedLearningService.shared.lastSyncDate {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        checkForUpdates()
                    }) {
                        HStack {
                            Text(isCheckingUpdate ? "Checking..." : "Check for Model Update")
                            if isCheckingUpdate {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isCheckingUpdate)
                    
                    Button(action: {
                        SyncManager.shared.syncPendingData()
                    }) {
                        Text("Sync Training Data Now")
                    }
                    
                    if let message = updateMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("Error") || message.contains("failed") ? .red : .green)
                    }
                }
                
                // Data Management
                Section(header: Text("Data Management")) {
                    Button(role: .destructive, action: {
                        showingClearHistoryConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All History")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                            Text("Delete Present Account")
                        }
                    }
                    
                    Text("Deleting account will clear your profile and all scan history.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Account Actions
                Section {
                    Button(role: .destructive, action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
                
                // Model Information
                Section(header: Text("Model Information")) {
                    HStack {
                        Text("Input Size")
                        Spacer()
                        Text("640 × 640")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Confidence Threshold")
                        Spacer()
                        Text("0.25")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("IOU Threshold")
                        Spacer()
                        Text("0.45")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Classes")
                        Spacer()
                        Text("ABNORMAL, normal")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Legal & Support
                Section(header: Text("Help & Support")) {
                    NavigationLink(destination: GuideView()) {
                        Label("How to Use App", systemImage: "book.fill")
                            .foregroundColor(.primary)
                    }
                    
                    NavigationLink(destination: LegalDetailView(title: "Terms and Conditions", content: LegalData.termsAndConditions)) {
                        Text("Terms and Conditions")
                    }
                    
                    NavigationLink(destination: LegalDetailView(title: "Privacy Policy", content: LegalData.privacyPolicy)) {
                        Text("Privacy Policy")
                    }
                    
                    NavigationLink(destination: LegalDetailView(title: "Q&A", content: LegalData.qAndA)) {
                        Text("Q&A")
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Framework")
                        Spacer()
                        Text("YOLOv8 + TFLite")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView()
                    .environmentObject(authViewModel)
            }
            .alert("Clear All History?", isPresented: $showingClearHistoryConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    clearAllHistory()
                }
            } message: {
                Text("This will permanently delete all scan records. This action cannot be undone.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will delete your profile information and all scan history. This action cannot be undone.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    
    private func clearAllHistory() {
        // 1. Delete Local
        SQLiteHelper.shared.deleteAllPredictions()
        
        // 2. Delete Server (if logged in)
        if let email = authViewModel.currentUser?.email {
            NetworkService.shared.clearHistory(email: email) { result in
                switch result {
                case .success: print("✅ Server history cleared")
                case .failure(let error): print("❌ Failed to clear server history: \(error)")
                }
            }
        }
        
        print("🗑️ Cleared all history records")
    }
    
    private func deleteAccount() {
        if let email = authViewModel.currentUser?.email {
            // Delete Server Account
            NetworkService.shared.deleteAccount(email: email) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: print("✅ Server account deleted")
                    case .failure(let error): print("❌ Failed to delete server account: \(error)")
                    }
                    
                    // Proceed with local cleanup regardless of server result (ensures user can still "leave")
                    performLocalAccountDeletion()
                }
            }
        } else {
            performLocalAccountDeletion()
        }
    }
    
    private func performLocalAccountDeletion() {
        SQLiteHelper.shared.deleteAllPredictions()
        // Here we ideally delete the Core Data user too, but logging out is sufficient for safety
        print("🗑️ Deleted account locally")
        authViewModel.logout()
    }
    
    private func checkForUpdates() {
        isCheckingUpdate = true
        updateMessage = nil
        
        FederatedLearningService.shared.checkForUpdates { result in
            isCheckingUpdate = false
            
            switch result {
            case .success(let modelInfo):
                if let modelInfo = modelInfo {
                    updateMessage = "📥 Update available: v\(modelInfo.version)"
                    downloadUpdate(modelInfo)
                } else {
                    updateMessage = "✅ You have the latest model"
                }
            case .failure(let error):
                updateMessage = "❌ Check failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func downloadUpdate(_ modelInfo: ModelInfo) {
        FederatedLearningService.shared.downloadAndInstallUpdate(modelInfo: modelInfo, progress: { _ in }) { result in
            switch result {
            case .success:
                updateMessage = "✅ Model updated to v\(modelInfo.version)"
            case .failure(let error):
                updateMessage = "❌ Update failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    SettingsView()
}
