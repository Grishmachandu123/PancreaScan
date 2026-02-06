//
//  ForgotPasswordView.swift
//  FederatedMLApp
//
//  Created for PancreaScan
//

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var step = 1 // 1: Email, 2: New Password
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "lock.rotation")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.orange)
                    
                    Text(step == 1 ? "Forgot Password" : "Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(step == 1 ? "Enter your email to verify account" : "Enter your new password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                if step == 1 {
                    // Step 1: Email Verification
                    VStack(spacing: 20) {
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        Button(action: verifyEmail) {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Verify Email")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(!email.isEmpty ? Color.orange : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(email.isEmpty || isProcessing)
                    }
                    .padding(.horizontal)
                    
                } else {
                    // Step 2: New Password (OTP Removed)
                    VStack(spacing: 20) {
                        Text("Resetting password for: \(email)")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "New Password", text: $newPassword)
                        CustomSecureField(icon: "lock.fill", placeholder: "Confirm New Password", text: $confirmPassword)
                        
                        if !newPassword.isEmpty && !authViewModel.isStrongPassword(newPassword) {
                             Text("Password must be 8+ chars, incl. uppercase, lowercase, number, & special char.")
                                 .font(.caption2)
                                 .foregroundColor(.orange)
                                 .multilineTextAlignment(.leading)
                        }
                        
                        Button(action: resetPassword) {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Reset Password")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(passwordsMatch ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!passwordsMatch || isProcessing)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK"), action: {
                if alertMessage == "Password successfully reset!" {
                    presentationMode.wrappedValue.dismiss()
                }
            }))
        }
    }
    
    var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword && authViewModel.isStrongPassword(newPassword)
    }
    
    func verifyEmail() {
        isProcessing = true
        // Check Local First
        authViewModel.checkEmailExists(email: email) { exists in
            if exists {
                isProcessing = false
                withAnimation {
                    step = 2
                }
            } else {
                // Not found locally? Check server (Recovery Mode)
                authViewModel.requestPasswordReset(email: email) { success in
                    isProcessing = false
                    if success {
                        // Server sent OTP (meaning user exists), so allow reset
                        withAnimation {
                            step = 2
                        }
                    } else {
                        alertMessage = "Account not found."
                        showAlert = true
                    }
                }
            }
        }
    }
    
    func resetPassword() {
        if newPassword != confirmPassword {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        isProcessing = true
        // Direct Local Update + Server Attempt
        authViewModel.resetPasswordDirectly(email: email, newPassword: newPassword) { success in
            isProcessing = false
            if success {
                alertMessage = "Password successfully reset!"
                showAlert = true
            } else {
                alertMessage = authViewModel.authError ?? "Failed to reset password."
                showAlert = true
            }
        }
    }
}
