//
//  ContentView.swift
//  Main content view with navigation between auth and dashboard

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Main Content
            if authViewModel.isAuthenticated {
                DashboardView()
                    .environmentObject(authViewModel)
            } else {
                IntroductionView()
                    .environmentObject(authViewModel)
            }
            
            // Splash Screen Overlay
            if authViewModel.showSplashScreen {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(\.managedObjectContext, viewContext)

    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
