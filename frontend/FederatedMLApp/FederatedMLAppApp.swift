//
//  FederatedMLAppApp.swift
//  FederatedMLApp
//
//  Created by SAIL on 24/11/25.
//

import SwiftUI

@main
struct FederatedMLAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
