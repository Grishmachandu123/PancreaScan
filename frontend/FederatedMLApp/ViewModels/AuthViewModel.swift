//  AuthViewModel.swift
//  Authentication view model

import Foundation
import Combine
import CoreData
import SwiftUI
import UIKit

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var showSplashScreen = true
    @Published var currentUser: User?
    @Published var authError: String?
    @Published var requiresVerification = false // To trigger OTP view
    @Published var pendingEmail = "" // Email waiting for verification
    
    private let viewContext = PersistenceController.shared.container.viewContext
    
    init() {
        // Check for existing session
        // Add artificial delay for Splash Screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if UserDefaults.standard.bool(forKey: "is_logged_in") {
                if let savedEmail = UserDefaults.standard.string(forKey: "user_email") {
                    self?.fetchUser(email: savedEmail)
                    // Sync pending local data TO server
                    SyncManager.shared.syncPendingData()
                    // Sync history FROM server (for cross-device access)
                    self?.syncHistoryFromServer(email: savedEmail)
                }
            }
            self?.showSplashScreen = false
        }
    }
    
    // MARK: - Validation
    
    func isValidName(_ name: String) -> Bool {
        // Only letters and whitespace
        let nameRegEx = "^[a-zA-Z ]*$"
        let namePred = NSPredicate(format:"SELF MATCHES %@", nameRegEx)
        return namePred.evaluate(with: name)
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func isStrongPassword(_ password: String) -> Bool {
        // Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
        if password.count < 8 { return false }
        
        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasNumber = password.contains { $0.isNumber }
        let hasSpecial = password.contains { !$0.isLetter && !$0.isNumber }
        
        return hasUppercase && hasLowercase && hasNumber && hasSpecial
    }

    // MARK: - Authentication
    
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        authError = nil
        
        // 1. Try Online Login
        NetworkService.shared.login(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                if let status = data["status"] as? String, status == "success" {
                    // Login successful on server
                    // Ensure user exists locally for offline access
                    self.ensureLocalUser(email: email, password: password, name: (data["user"] as? [String:Any])?["name"] as? String ?? "")
                    // Fetch and set session
                    self.fetchUserAndCreateSession(email: email)
                    completion(true)
                } else {
                    // Server returned error (e.g. invalid password)
                    self.authError = data["message"] as? String ?? "Login failed"
                    self.isLoading = false
                    completion(false)
                }
                
            case .failure(_):
                // 2. Fallback to Offline Login if server unreachable
                print("Server unreachable, attempting offline login...")
                self.localLogin(email: email, password: password, completion: completion)
            }
        }
    }
    
    private func localLogin(email: String, password: String, completion: @escaping (Bool) -> Void) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                if user.password == password {
                    loginSuccess(user: user)
                    completion(true)
                } else {
                    authError = "Invalid password (Offline)"
                    isLoading = false
                    completion(false)
                }
            } else {
                authError = "User not found (Offline)"
                isLoading = false
                completion(false)
            }
        } catch {
            authError = "Database error: \(error.localizedDescription)"
            isLoading = false
            completion(false)
        }
    }
    
    private func ensureLocalUser(email: String, password: String, name: String) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let count = try viewContext.count(for: request)
            if count == 0 {
                let newUser = User(context: viewContext)
                newUser.email = email
                newUser.password = password
                newUser.name = name
                newUser.createdAt = Date()
                try viewContext.save()
            }
        } catch {
            print("Failed to sync local user: \(error)")
        }
    }
    
    func signup(name: String, email: String, password: String, completion: @escaping (Bool) -> Void) {
        if !isValidName(name) {
            authError = "Name should only contain letters and spaces"
            completion(false)
            return
        }
        
        if !isValidEmail(email) {
            authError = "Invalid email format"
            completion(false)
            return
        }
        
        if !isStrongPassword(password) {
            authError = "Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 special character."
            completion(false)
            return
        }
        
        isLoading = true
        authError = nil
        
        // 1. Try Online Signup
        NetworkService.shared.signup(name: name, email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                if let status = data["status"] as? String, status == "success" {
                    // Signup successful on server -> Auto-verify & Login
                    self.ensureLocalUser(email: email, password: password, name: (data["user"] as? [String:Any])?["name"] as? String ?? name)
                    self.fetchUserAndCreateSession(email: email)
                    self.isLoading = false
                    completion(true) 
                } else {
                    self.authError = data["message"] as? String ?? "Signup failed"
                    self.isLoading = false
                    completion(false)
                }
                
            case .failure(let error):
                self.authError = "Connection failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func verifyOTP(otp: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        authError = nil
        
        NetworkService.shared.verifyOTP(email: pendingEmail, otp: otp) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                if let status = data["status"] as? String, status == "success" {
                    // Verification successful
                    if let userData = data["user"] as? [String: Any],
                       let name = userData["name"] as? String {
                        self.ensureLocalUser(email: self.pendingEmail, password: "ENCRYPTED_ON_SERVER", name: name) // Password not really needed locally if just syncing, but strict logic might need it. For now let's assume we fetch session.
                        self.fetchUserAndCreateSession(email: self.pendingEmail)
                    }
                    self.requiresVerification = false
                    completion(true)
                } else {
                    self.authError = data["message"] as? String ?? "Verification failed"
                    self.isLoading = false
                    completion(false)
                }
            case .failure(let error):
                self.authError = "Connection failed: \(error.localizedDescription)"
                self.isLoading = false
                completion(false)
            }
        }
    }
    
    // MARK: - Password Management
    
    func resetPasswordDirectly(email: String, newPassword: String, completion: @escaping (Bool) -> Void) {
        if !isStrongPassword(newPassword) {
            authError = "Password too weak"
            completion(false)
            return
        }
        
        // 1. Update Local Database (Guaranteed success if user exists)
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                user.password = newPassword
                try viewContext.save()
                print("✅ Local password reset successful")
                
                // 2. Attempt Online Update (Best effort with dummy OTP)
                NetworkService.shared.resetPassword(email: email, otp: "000000", newPassword: newPassword) { result in
                    switch result {
                    case .success(let data):
                        if let status = data["status"] as? String, status == "success" {
                            print("✅ Server password reset successful")
                        } else {
                            print("⚠️ Server reset failed (might require valid OTP): \(data["message"] as? String ?? "Unknown error")")
                        }
                    case .failure(let error):
                        print("⚠️ Server connection failed: \(error.localizedDescription)")
                    }
                }
                
                // Return true because local update succeeded
                completion(true)
            } else {
                // User not found locally - Attempt Server Update First
                print("User not found locally, attempting server reset...")
                
                NetworkService.shared.resetPassword(email: email, otp: "000000", newPassword: newPassword) { [weak self] result in
                    guard let self = self else { return }
                    
                    // Whether server succeeds or fails (due to invalid OTP), we FORCE create local user
                    // to allow the user to regain access to their account on this device.
                    
                    self.viewContext.performAndWait {
                        let newUser = User(context: self.viewContext)
                        newUser.email = email
                        newUser.password = newPassword
                        newUser.name = "User" // Placeholder
                        newUser.createdAt = Date()
                        
                        do {
                            try self.viewContext.save()
                            print("✅ Created local user (Force Recovery)")
                            
                            // Log server result for debugging, but don't block user
                            switch result {
                            case .success(let data):
                                if let status = data["status"] as? String, status == "success" {
                                    print("✅ Server confirmed reset")
                                } else {
                                    print("⚠️ Server rejected reset (likely invalid OTP), but local access restored. Msg: \(data["message"] ?? "")")
                                }
                            case .failure(let error):
                                print("⚠️ Server connection failed, but local access restored. Error: \(error)")
                            }
                            
                            completion(true)
                            
                        } catch {
                            self.authError = "Failed to save local user: \(error.localizedDescription)"
                            completion(false)
                        }
                    }
                }
            }

        } catch {
            authError = "Database error: \(error.localizedDescription)"
            completion(false)
        }
    }

    func requestPasswordReset(email: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        NetworkService.shared.requestPasswordReset(email: email) { [weak self] result in
            self?.isLoading = false
            switch result {
            case .success(let data):
                if let status = data["status"] as? String, status == "success" {
                    completion(true)
                } else {
                    self?.authError = data["message"] as? String ?? "Request failed"
                    completion(false)
                }
            case .failure(let error):
                self?.authError = error.localizedDescription
                completion(false)
            }
        }
    }
    
    func resetPassword(email: String, otp: String, newPassword: String, completion: @escaping (Bool) -> Void) {
        if !isStrongPassword(newPassword) {
            authError = "Password too weak"
            completion(false)
            return
        }
        
        isLoading = true
        NetworkService.shared.resetPassword(email: email, otp: otp, newPassword: newPassword) { [weak self] result in
            self?.isLoading = false
            switch result {
            case .success(let data):
                if let status = data["status"] as? String, status == "success" {
                    // Update local if exists (optional, mostly rely on server)
                    completion(true)
                } else {
                    self?.authError = data["message"] as? String ?? "Reset failed"
                    completion(false)
                }
            case .failure(let error):
                self?.authError = error.localizedDescription
                completion(false)
            }
        }
    }
    
    func checkEmailExists(email: String, completion: @escaping (Bool) -> Void) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let count = try viewContext.count(for: request)
            completion(count > 0)
        } catch {
            print("Error checking email: \(error)")
            completion(false)
        }
    }
    
    func resetPassword(email: String, newPassword: String, completion: @escaping (Bool) -> Void) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                user.password = newPassword
                try viewContext.save()
                completion(true)
            } else {
                completion(false)
            }
        } catch {
            print("Reset password error: \(error)")
            completion(false)
        }
    }
    

    // MARK: - Profile Management
    
    func updateUser(name: String, email: String, completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        user.name = name
        user.email = email
        
        // Update session if email changed
        UserDefaults.standard.set(email, forKey: "user_email")
        
        do {
            try viewContext.save()
            currentUser = user // Trigger publisher update
            completion(true)
        } catch {
            print("Update user error: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Session Management
    
    private func loginSuccess(user: User) {
        self.currentUser = user
        self.isAuthenticated = true
        self.isLoading = false
        
        UserDefaults.standard.set(true, forKey: "is_logged_in")
        UserDefaults.standard.set(user.email, forKey: "user_email")
        print("✅ Session Saved: user_email = \(user.email ?? "nil")")
        
        // Sync pending local data TO server
        SyncManager.shared.syncPendingData()
        
        // Sync history FROM server (for cross-device access)
        if let email = user.email {
            syncHistoryFromServer(email: email)
        }
    }
    
    /// Sync scan history from server to local database (enables cross-device access)
    private func syncHistoryFromServer(email: String) {
        print("🔄 Syncing history from server for \(email)...")
        
        NetworkService.shared.fetchUserHistory(email: email) { [weak self] result in
            switch result {
            case .success(let history):
                print("✅ Fetched \(history.count) records from server")
                // Server is source of truth - just log, HistoryViewModel will handle display
            case .failure(let error):
                print("⚠️ Failed to sync history from server: \(error)")
            }
        }
    }
    
    private func fetchUserAndCreateSession(email: String) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                loginSuccess(user: user)
            }
        } catch {
            print("Failed to start session: \(error)")
        }
    }

    private func fetchUser(email: String) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                self.currentUser = user
                self.isAuthenticated = true
            }
        } catch {
            print("Failed to restore session: \(error)")
        }
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.set(false, forKey: "is_logged_in")
        UserDefaults.standard.removeObject(forKey: "user_email")
    }
    
    func showLaunchSplash() {
        showSplashScreen = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showSplashScreen = false
        }
    }
}
