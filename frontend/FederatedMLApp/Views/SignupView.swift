//
//  SignupView.swift
//  FederatedMLApp
//
//  Created for PancreaScan
//

import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSigningUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.green)
                        
                        Text("Create Account")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Join PancreaScan to manage your analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        CustomTextField(icon: "person.fill", placeholder: "Full Name", text: $name)
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                        if !password.isEmpty && !authViewModel.isStrongPassword(password) {
                             Text("Password must be 8+ chars, incl. uppercase, lowercase, number, & special char.")
                                 .font(.caption2)
                                 .foregroundColor(.orange)
                                 .multilineTextAlignment(.leading)
                        }
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword)
                    }
                    .padding(.horizontal)
                    
                    if let error = authViewModel.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Action Button
                    Button(action: signup) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(isValid ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(!isValid || authViewModel.isLoading)
                    
                }
                .padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .sheet(isPresented: $authViewModel.requiresVerification) {
            OTPVerificationView()
                .environmentObject(authViewModel)
        }
    }
    
    var isValid: Bool {
        !name.isEmpty && 
        authViewModel.isValidName(name) &&
        authViewModel.isValidEmail(email) && 
        authViewModel.isStrongPassword(password) && 
        password == confirmPassword
    }
    
    func signup() {
        if password != confirmPassword {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        authViewModel.signup(name: name, email: email, password: password) { success in
            if !success {
                // Error handled by ViewModel binding usually, but we can set extra alert
            }
        }
    }
}

// Helper Views
struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            SecureField(placeholder, text: $text)
                .textContentType(.oneTimeCode)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}
