//  SplashView.swift
//  App loading splash screen

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.green)
                
                Text("PancreaScan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                
                Text("Loading AI Model...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
