//  DashboardView.swift
//  Main dashboard with tab navigation

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            HomeTabView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
            
            // Settings Tab
            SettingsView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
    }
}

struct HomeTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage("use_online_mode") private var useOnlineMode = false
    @State private var showNewAnalysis = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hello, \(authViewModel.currentUser?.name ?? "Doctor")")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("Dashboard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "house.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                    .padding()
                    
                    // Start New Analysis Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Start New Analysis")
                            .font(.headline)
                        
                        Text("Upload image for AI-powered detection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showNewAnalysis = true }) {
                            Label("Upload Image", systemImage: "arrow.up.doc")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(color: .green.opacity(0.2), radius: 10)
                    .padding(.horizontal)
                    
                    // Stats Card (Moved Below)
                    HStack(spacing: 15) {
                        StatCard(title: "Total", value: viewModel.totalScans, color: .blue)
                        StatCard(title: "Normal", value: viewModel.normalScans, color: .green)
                        StatCard(title: "Abnormal", value: viewModel.abnormalScans, color: .red)
                    }
                    .padding(.horizontal)
                    
                    // Model Info Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Model Information")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Version")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(FederatedLearningService.shared.currentModelVersion)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Mode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                // Show Online only if Sync is enabled AND Network is available
                                // OR if user considers "Mode" as just Connectivity, maybe just show connectivity?
                                // Let's respect the preference BUT show actual status
                                let isOnline = useOnlineMode && networkMonitor.isConnected
                                Text(isOnline ? "Online" : "Offline")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isOnline ? .blue : .green)
                            }

                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // User Info
                    if let user = authViewModel.currentUser {
                        VStack(spacing: 5) {
                            Text("Logged in as: \(user.email ?? "User")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: { authViewModel.logout() }) {
                                Text("Log Out")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .fullScreenCover(isPresented: $showNewAnalysis) {
                NewAnalysisView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                viewModel.loadStats()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            AnimatingNumber(number: animatedValue, color: color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                animatedValue = Double(value)
            }
        }
        .onChange(of: value) { newValue in
            withAnimation(.easeOut(duration: 1.5)) {
                animatedValue = Double(newValue)
            }
        }
    }
}

struct AnimatingNumber: View, Animatable {
    var number: Double
    var color: Color
    
    var animatableData: Double {
        get { number }
        set { number = newValue }
    }
    
    var body: some View {
        Text("\(Int(number))")
            .font(.system(size: 40, weight: .bold)) // Increased size
            .foregroundColor(color)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthViewModel())
}
