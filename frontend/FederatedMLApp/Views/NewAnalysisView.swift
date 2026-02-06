//  NewAnalysisView.swift
//  Image analysis view (matching PancreasEdemaAI design)

import SwiftUI
import PhotosUI

struct NewAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = AnalysisViewModel()
    
    @State private var patientId = ""
    @State private var patientName = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("New Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding()
                    
                    // Patient Information Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Patient Information")
                            .font(.headline)
                        
                        TextField("Patient ID", text: $patientId)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .keyboardType(.numberPad)
                            .onChange(of: patientId) { newValue in
                                // Restrict to numbers only
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    patientId = filtered
                                }
                                
                                // Auto-fill Patient Name if ID exists in history
                                if !patientId.isEmpty {
                                    lookUpPatientName(for: patientId)
                                }
                            }
                        
                        TextField("Patient Name", text: $patientName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: patientName) { newValue in
                                // Restrict to characters only (letters and spaces) and max length 25
                                let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
                                let truncated = String(filtered.prefix(25))
                                
                                if truncated != newValue {
                                    patientName = truncated
                                }
                            }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // Upload Image Card
                    VStack(spacing: 15) {
                        Text("Upload Image")
                            .font(.headline)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400) // Adaptive height
                                .cornerRadius(10)
                                .onTapGesture {
                                    // Tapping on image allows re-selection
                                }
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .foregroundColor(.gray)
                                
                                Text("No image selected")
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showImagePicker = true }) {
                            Text("Select Image")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: analyzeImage) {
                            if viewModel.isAnalyzing {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Analyzing...")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            } else {
                                Label("Analyze Image", systemImage: "waveform.path.ecg")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(canAnalyze ? Color.green : Color.gray.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(!canAnalyze || viewModel.isAnalyzing)
                        .allowsHitTesting(canAnalyze && !viewModel.isAnalyzing) // Extra protection against double-tap
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel")
                        }
                        .foregroundColor(.green)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .fullScreenCover(isPresented: $showResults) {
                if let result = viewModel.analysisResult, let image = selectedImage {
                    ResultsView(
                        result: result,
                        originalImage: image,
                        patientName: patientName,
                        patientId: patientId
                    )
                }
            }
            .onChange(of: viewModel.analysisResult) { newValue in
                if newValue != nil {
                    showResults = true
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    
    private var canAnalyze: Bool {
        !patientId.isEmpty && !patientName.isEmpty && selectedImage != nil
    }
    
    private func lookUpPatientName(for id: String) {
        // Query SQLite directly for the most recent name associated with this ID
        // Note: SQLiteHelper is the source of truth for offline/cached data
        if let userEmail = UserDefaults.standard.string(forKey: "user_email") {
            let records = SQLiteHelper.shared.getAllPredictions(for: userEmail)
            // Find the most recent record with this Patient ID
            if let match = records.filter({ $0.patientId == id }).sorted(by: { $0.timestamp > $1.timestamp }).first {
                // Only auto-fill if the name field is empty or user is just starting to type ID
                if patientName.isEmpty {
                    patientName = match.patientName
                }
            }
        }
    }
    
    private func analyzeImage() {
        guard let image = selectedImage else { return }
        
        // Use a random UUID for physicianId since User entity doesn't have a UUID attribute
        let userUUID = UUID()
        
        viewModel.analyzeImage(image, patientId: patientId, patientName: patientName, physicianId: userUUID)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NewAnalysisView()
        .environmentObject(AuthViewModel())
}
