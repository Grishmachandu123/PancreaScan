//  GuideView.swift
//  User guide and help documentation

import SwiftUI

struct GuideView: View {
    var body: some View {
        List {
            // Section 1: Introduction
            Section(header: Text("Welcome")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to FederatedMLApp")
                        .font(.headline)
                    Text("This app uses advanced AI to analyze pancreas CT scans directly on your device. We prioritize your privacy using Federated Learning.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Section 2: How to Use
            Section(header: Text("How to Use")) {
                GuideRow(icon: "arrow.up.doc.fill", color: .blue, title: "1. Upload Scan", description: "Go to the Dashboard and tap 'Upload Image'. Select a clear CT scan of the pancreas from your gallery.")
                GuideRow(icon: "brain.head.profile", color: .purple, title: "2. AI Analysis", description: "The app analyzes the image in seconds. It detects abnormalities and highlights them with bounding boxes.")
                GuideRow(icon: "checkmark.shield.fill", color: .green, title: "3. Review Results", description: "You will see a diagnosis (Normal or Abnormal). You can view detailed metrics like circularity and lobulation.")
            }
            
            // Section 3: Federated Learning
            Section(header: Text("Improving the AI")) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("What is Federated Learning?", systemImage: "network")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Unlike traditional AI, we don't send your raw images to a central server to train the model. Instead:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("•")
                            Text("The model trains locally on your device using your feedback.")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Only the mathematical 'lessons' (gradients) are shared with the server.")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Your patient data never leaves your phone unless you choose to sync it.")
                        }
                    }
                    .font(.caption)
                    .padding(.leading, 10)
                }
                .padding(.vertical, 8)
                
                GuideRow(icon: "hand.thumbsup.fill", color: .orange, title: "Provide Feedback", description: "At the bottom of the result screen, tell us if the AI was Correct or Incorrect. This helps the global model get smarter for everyone!")
            }
            
            // Section 4: Privacy & Sync
            Section(header: Text("Data & Sync")) {
                GuideRow(icon: "wifi", color: .blue, title: "Online Mode", description: "When online, your scans are backed up to our secure server so you can access them on other devices.")
                GuideRow(icon: "wifi.slash", color: .gray, title: "Offline Mode", description: "No internet? No problem. The AI works 100% offline. Data is saved locally and syncs when you reconnect.")
            }
        }
        .navigationTitle("App Guide")

    }
}



struct GuideRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    NavigationView {
        GuideView()
    }
}
