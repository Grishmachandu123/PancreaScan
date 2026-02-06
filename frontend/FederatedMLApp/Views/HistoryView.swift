//  HistoryView.swift
//  Patient history with search and date grouping

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedRecord: (id: Int64, imagePath: String, result: String, confidence: Double, timestamp: Date)?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if viewModel.filteredRecords.isEmpty {
                    emptyState
                } else {
                    patientList
                }
            }
            .navigationTitle("Patient History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.allRecords.isEmpty {
                        Button(action: {
                            viewModel.loadRecords()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }

        .onAppear {
            viewModel.loadRecords()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search by patient name or ID", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Patients Found")
                .font(.title2)
                .fontWeight(.semibold)
            if viewModel.isLoading {
                ProgressView("Syncing history...")
                    .padding()
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Text(viewModel.searchText.isEmpty ? "Your patient history will appear here" : "No results for '\(viewModel.searchText)'")
                .foregroundColor(.secondary)
            
            Button(action: {
                viewModel.loadRecords()
            }) {
                Text("Refresh History")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var patientList: some View {
        List {
            ForEach(viewModel.uniquePatients, id: \.uuid) { patient in
                NavigationLink(destination: PatientDetailView(viewModel: viewModel, patientId: patient.id, patientName: patient.name)) {
                    HStack(spacing: 15) {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(String(patient.name.prefix(1)))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(patient.name)
                                .font(.headline)
                            Text("ID: \(patient.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Last Scan")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(patient.lastScan, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct PatientDetailView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let patientId: String
    let patientName: String
    
    struct RecordWrapper: Identifiable {
        let id = UUID()
        let record: HistoryViewModel.HistoryRecord
    }
    
    @State private var selectedWrapper: RecordWrapper?
    
    var body: some View {
        List {
            ForEach(patientRecords, id: \.id) { record in
                HistoryRowView(record: record)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedWrapper = RecordWrapper(record: record)
                    }
            }
            .onDelete { indexSet in
                viewModel.deleteRecord(at: indexSet, in: patientRecords)
            }
        }
        .navigationTitle(patientName)
        .sheet(item: $selectedWrapper) { wrapper in
            let record = wrapper.record
            let result = reconstructResult(from: record)
            
            if let image = UIImage(contentsOfFile: record.imagePath) {
                ResultsView(
                    result: result,
                    originalImage: image,
                    patientName: record.patientName,
                    patientId: record.patientId
                )
            } else {
                Text("Error loading image")
            }
        }
    }
    
    private var patientRecords: [HistoryViewModel.HistoryRecord] {
        let key = "\(patientId)|\(patientName)"
        return viewModel.groupedByPatient[key]?.sorted { $0.timestamp > $1.timestamp } ?? []
    }
    
    private func reconstructResult(from record: HistoryViewModel.HistoryRecord) -> AnalysisResult {
        // Calculate metrics if available (matching AnalysisViewModel logic)
        var lobulationScore: Float?
        var circularity: Float?
        var convexity: Float?
        
        if let abnormalDetection = record.detections.first(where: { $0.classId == 0 }),
           let mask = abnormalDetection.mask {
            let metrics = MaskAnalyzer.analyze(mask: mask, width: 128, height: 128)
            lobulationScore = metrics.lobulation
            circularity = metrics.circularity
            convexity = metrics.convexity
        }

        // Reconstruct AnalysisResult for detail view
        return AnalysisResult(
            id: UUID(),
            patientId: record.patientId,
            patientName: record.patientName,
            timestamp: record.timestamp,
            diagnosis: record.result,
            confidence: Float(record.confidence),
            detections: record.detections,
            inferenceMode: "Offline",
            lobulationScore: lobulationScore,
            circularity: circularity,
            convexity: convexity,
            qualityWarnings: []
        )
    }
}

struct HistoryRowView: View {
    let record: HistoryViewModel.HistoryRecord
    
    var body: some View {
        HStack(spacing: 15) {
            // Thumbnail
            if let image = UIImage(contentsOfFile: record.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.result)
                    .font(.headline)
                    .foregroundColor(record.result == "ABNORMAL" ? .red : .green)
                
                Text("Confidence: \(Int(record.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(record.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
}
