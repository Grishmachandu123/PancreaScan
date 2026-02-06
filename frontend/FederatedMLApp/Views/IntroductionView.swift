//  IntroductionView.swift
//  Landing page for unauthenticated users

import SwiftUI

struct IntroductionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo / Title area
                VStack(spacing: 15) {
                    Image(systemName: "brain.head.profile") // Using SF Symbol as logo placeholder
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundColor(.green)
                    
                    Text("PancreasScan")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Early Detection")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 20) {
                    NavigationLink(destination: LoginView().environmentObject(authViewModel)) {
                        Text("Log In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: SignupView().environmentObject(authViewModel)) {
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }

            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


#Preview {
    IntroductionView()
        .environmentObject(AuthViewModel())
}
