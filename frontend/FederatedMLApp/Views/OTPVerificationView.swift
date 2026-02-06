//
//  OTPVerificationView.swift
//  FederatedMLApp
//
//  Created for PancreaScan
//

import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var otpCode = ""
    @State private var isVerifying = false
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            VStack(spacing: 10) {
                Text("Verify Your Email")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter the 6-digit code sent to\n\(authViewModel.pendingEmail)")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // OTP Entry
            HStack(spacing: 15) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitField(index: index, text: $otpCode)
                }
            }
            .padding()
            
            if let error = authViewModel.authError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: verify) {
                if authViewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Verify Code")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(otpCode.count == 6 ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(otpCode.count != 6 || authViewModel.isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 50)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    func verify() {
        authViewModel.verifyOTP(otp: otpCode) { success in
            // ViewModel handles navigation on success
        }
    }
}

// Helper for single digit entry (Simplified for this demo, usually requires FocusState management)
struct OTPDigitField: View {
    let index: Int
    @Binding var text: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .background(Color(.systemBackground))
                .frame(width: 45, height: 55)
            
            if text.count > index {
                let startIndex = text.index(text.startIndex, offsetBy: index)
                let char = String(text[startIndex])
                Text(char)
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
        .overlay(
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(width: 45, height: 55)
                .opacity(0.01) // Invisible overlay to capture taps
                .onChange(of: text) { newValue in
                    if newValue.count > 6 {
                        text = String(newValue.prefix(6))
                    }
                }
        )
    }
}
