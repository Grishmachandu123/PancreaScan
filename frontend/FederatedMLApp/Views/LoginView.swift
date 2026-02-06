//  LoginView.swift
//  User login view (matching PancreasEdemaAI design)

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showAuthError = false
    
    var body: some View {
        ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo
                    VStack(spacing: 15) {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.green)
                            .shadow(radius: 5)
                        
                        Text("PancreaScan")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("AI-Powered Medical Analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = authViewModel.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Login Form
                    VStack(spacing: 20) {
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                        
                        // Forgot Password Link
                        HStack {
                            Spacer()
                            NavigationLink(destination: ForgotPasswordView()) {
                                Text("Forgot Password?")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: login) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canLogin ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!canLogin || authViewModel.isLoading)
                    }
                    .padding(.horizontal, 30)
                    
                    // Signup Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        NavigationLink(destination: SignupView()) {
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .font(.footnote)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }

    
    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty && authViewModel.isValidEmail(email)
    }
    
    private func login() {
        authViewModel.login(email: email, password: password) { success in
            if !success {
                showAuthError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
