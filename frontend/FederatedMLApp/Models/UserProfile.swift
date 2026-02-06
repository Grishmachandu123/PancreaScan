//  UserProfile.swift
//  User profile model

import Foundation

struct UserProfile: Codable {
    var name: String
    var email: String
    var institution: String
    var licenseNumber: String
    
    static let `default` = UserProfile(
        name: "",
        email: "",
        institution: "",
        licenseNumber: ""
    )
    
    // UserDefaults key
    private static let storageKey = "UserProfile"
    
    // Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
    
    // Load from UserDefaults
    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .default
        }
        return profile
    }
}
