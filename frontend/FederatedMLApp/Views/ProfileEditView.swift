//  ProfileEditView.swift
//  Edit user profile

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    HStack {
                        Text("Name")
                        TextField("Full Name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Email")
                        TextField("email@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button(action: saveProfile) {
                        HStack {
                            Spacer()
                            Text("Save Profile")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let user = authViewModel.currentUser {
                    name = user.name ?? ""
                    email = user.email ?? ""
                }
            }
            .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your profile has been updated successfully.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    
    private func saveProfile() {
        authViewModel.updateUser(name: name, email: email) { success in
            if success {
                showingSaveConfirmation = true
            }
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(AuthViewModel())
}
