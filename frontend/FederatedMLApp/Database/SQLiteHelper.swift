import Foundation
import CoreData

class SQLiteHelper {
    static let shared = SQLiteHelper()
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FederatedMLApp")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {
        // Initialize if needed
        print("✅ Core Data initialized successfully")
    }
    
    // MARK: - ScanHistory Operations
    
    func insertPrediction(imagePath: String, result: String, confidence: Double, patientId: String, patientName: String, userEmail: String, timestamp: Date = Date()) -> Int64? {
        // Check for duplicate: same patient + user + result within 60 seconds
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        let sixtySecondsAgo = timestamp.addingTimeInterval(-60)
        fetchRequest.predicate = NSPredicate(
            format: "patientId == %@ AND userEmail == %@ AND timestamp >= %@",
            patientId, userEmail, sixtySecondsAgo as NSDate
        )
        
        do {
            let existingCount = try context.count(for: fetchRequest)
            if existingCount > 0 {
                print("⏭️ Duplicate prevention: Recent scan for patient \(patientId) already exists, skipping insert.")
                // Return the existing record's ID
                let results = try context.fetch(fetchRequest)
                if let existing = results.first, let existingId = existing.value(forKey: "id") as? Int64 {
                    return existingId
                }
                return nil
            }
        } catch {
            print("Duplicate check error: \(error)")
        }
        
        let prediction = NSEntityDescription.insertNewObject(forEntityName: "ScanHistory", into: context)
        prediction.setValue(imagePath, forKey: "imagePath")
        prediction.setValue(result, forKey: "result")
        prediction.setValue(confidence, forKey: "confidence")
        prediction.setValue(timestamp, forKey: "timestamp")
        prediction.setValue(false, forKey: "synced")
        prediction.setValue(patientId, forKey: "patientId")
        prediction.setValue(patientName, forKey: "patientName")
        prediction.setValue(userEmail, forKey: "userEmail")
        
        let id = Int64(timestamp.timeIntervalSince1970 * 1000) // Unique ID based on timestamp (ms)
        prediction.setValue(id, forKey: "id")
        
        do {
            try context.save()
            return id
        } catch {
            print("Insert prediction error: \(error)")
            return nil
        }
    }
    
    func insertSyncedPrediction(id: Int64, imagePath: String, result: String, confidence: Double, timestamp: Date, patientId: String, patientName: String, userEmail: String) -> Bool {
        // Check if exists by ID first
        let fetchById = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchById.predicate = NSPredicate(format: "id == %lld", id)
        
        do {
            if try context.count(for: fetchById) > 0 {
                print("⏭️ Record with id \(id) already exists, skipping.")
                return false // Already exists by ID
            }
            
            // Check by patient + user within 2 minutes window (handles timezone/formatting differences)
            let twoMinutesBefore = timestamp.addingTimeInterval(-120)
            let twoMinutesAfter = timestamp.addingTimeInterval(120)
            let fetchByContent = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
            fetchByContent.predicate = NSPredicate(
                format: "patientId == %@ AND userEmail == %@ AND timestamp >= %@ AND timestamp <= %@",
                patientId, userEmail, twoMinutesBefore as NSDate, twoMinutesAfter as NSDate
            )
            
            if try context.count(for: fetchByContent) > 0 {
                print("⏭️ Record with same patient within 2 minutes already exists, skipping server record.")
                return false // Duplicate content
            }
            
            let prediction = NSEntityDescription.insertNewObject(forEntityName: "ScanHistory", into: context)
            prediction.setValue(id, forKey: "id")
            prediction.setValue(imagePath, forKey: "imagePath")
            prediction.setValue(result, forKey: "result")
            prediction.setValue(confidence, forKey: "confidence")
            prediction.setValue(timestamp, forKey: "timestamp")
            prediction.setValue(true, forKey: "synced") // Mark as valid/synced
            prediction.setValue(patientId, forKey: "patientId")
            prediction.setValue(patientName, forKey: "patientName")
            prediction.setValue(userEmail, forKey: "userEmail")
            
            try context.save()
            return true
        } catch {
            print("Insert synced prediction error: \(error)")
            return false
        }
    }
    
    func getUnsyncedPredictions(for userEmail: String? = nil) -> [(id: Int64, imagePath: String, result: String, confidence: Double, timestamp: Date, patientId: String, patientName: String, userEmail: String)] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        
        var predicates: [NSPredicate] = [NSPredicate(format: "synced == %@", NSNumber(value: false))]
        if let email = userEmail {
            predicates.append(NSPredicate(format: "userEmail == %@", email))
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { object in
                guard let imagePath = object.value(forKey: "imagePath") as? String,
                      let result = object.value(forKey: "result") as? String,
                      let confidence = object.value(forKey: "confidence") as? Double,
                      let timestamp = object.value(forKey: "timestamp") as? Date else {
                    return nil
                }
                let id = object.value(forKey: "id") as? Int64 ?? 0
                let patientId = object.value(forKey: "patientId") as? String ?? "Unknown"
                let patientName = object.value(forKey: "patientName") as? String ?? "Unknown"
                let email = object.value(forKey: "userEmail") as? String ?? ""
                return (id, imagePath, result, confidence, timestamp, patientId, patientName, email)
            }
        } catch {
            print("Get unsynced predictions error: \(error)")
            return []
        }
    }
    
    func markPredictionSynced(id: Int64) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            results.first?.setValue(true, forKey: "synced")
            try context.save()
        } catch {
            print("Mark prediction synced error: \(error)")
        }
    }
    
    func getAllPredictions(for userEmail: String) -> [(id: Int64, imagePath: String, result: String, confidence: Double, timestamp: Date, patientId: String, patientName: String)] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchRequest.predicate = NSPredicate(format: "userEmail == %@", userEmail)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { object in
                guard let imagePath = object.value(forKey: "imagePath") as? String,
                      let result = object.value(forKey: "result") as? String,
                      let confidence = object.value(forKey: "confidence") as? Double,
                      let timestamp = object.value(forKey: "timestamp") as? Date else {
                    return nil
                }
                let id = object.value(forKey: "id") as? Int64 ?? 0
                let patientId = object.value(forKey: "patientId") as? String ?? "Unknown"
                let patientName = object.value(forKey: "patientName") as? String ?? "Unknown"
                return (id, imagePath, result, confidence, timestamp, patientId, patientName)
            }
        } catch {
            print("Get all predictions error: \(error)")
            return []
        }
    }
    
    func deletePrediction(id: Int64) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let object = results.first {
                context.delete(object)
                try context.save()
            }
        } catch {
            print("Delete prediction error: \(error)")
        }
    }
    
    func deleteAllPredictions() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ScanHistory")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("✅ All history records deleted")
        } catch {
            print("Delete all predictions error: \(error)")
        }
    }
    
    /// Remove duplicate records, keeping only the first (oldest) record for each patient+user combination within 2 minutes
    func cleanupDuplicates(for userEmail: String) -> Int {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchRequest.predicate = NSPredicate(format: "userEmail == %@", userEmail)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        var deletedCount = 0
        
        do {
            let results = try context.fetch(fetchRequest)
            var seenPatients: [String: Date] = [:] // patientId -> earliest timestamp
            var toDelete: [NSManagedObject] = []
            
            for record in results {
                guard let patientId = record.value(forKey: "patientId") as? String,
                      let timestamp = record.value(forKey: "timestamp") as? Date else {
                    continue
                }
                
                if let existingTimestamp = seenPatients[patientId] {
                    // Check if within 2 minutes of existing record
                    let timeDiff = abs(timestamp.timeIntervalSince(existingTimestamp))
                    if timeDiff < 120 { // Within 2 minutes = duplicate
                        toDelete.append(record)
                    } else {
                        // Different scan session, update the reference
                        seenPatients[patientId] = timestamp
                    }
                } else {
                    seenPatients[patientId] = timestamp
                }
            }
            
            // Delete duplicates
            for record in toDelete {
                context.delete(record)
                deletedCount += 1
            }
            
            if deletedCount > 0 {
                try context.save()
                print("🧹 Cleaned up \(deletedCount) duplicate records")
            }
            
        } catch {
            print("Cleanup duplicates error: \(error)")
        }
        
        return deletedCount
    }
    
    func getStats(for userEmail: String) -> (total: Int, normal: Int, abnormal: Int) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScanHistory")
        fetchRequest.predicate = NSPredicate(format: "userEmail == %@", userEmail)
        
        do {
            let results = try context.fetch(fetchRequest)
            let total = results.count
            var normal = 0
            var abnormal = 0
            
            for object in results {
                if let result = object.value(forKey: "result") as? String {
                    if result.lowercased().contains("abnormal") {
                        abnormal += 1
                    } else {
                        normal += 1
                    }
                }
            }
            
            return (total, normal, abnormal)
        } catch {
            print("Get stats error: \(error)")
            return (0, 0, 0)
        }
    }
    
    // MARK: - FLUpdates Operations
    
    func insertFLUpdate(update: Data, round: Int, userEmail: String) -> Int64? {
        let flUpdate = NSEntityDescription.insertNewObject(forEntityName: "FLUpdates", into: context)
        flUpdate.setValue(update, forKey: "update")
        flUpdate.setValue(round, forKey: "round")
        flUpdate.setValue(false, forKey: "synced")
        flUpdate.setValue(userEmail, forKey: "userEmail")
        
        do {
            try context.save()
            return flUpdate.value(forKey: "id") as? Int64 ?? Int64(Date().timeIntervalSince1970)
        } catch {
            print("Insert FL update error: \(error)")
            return nil
        }
    }
    
    func getUnsyncedFLUpdates() -> [(id: Int64, update: Data, round: Int)] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FLUpdates")
        fetchRequest.predicate = NSPredicate(format: "synced == %@", NSNumber(value: false))
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { object in
                guard let update = object.value(forKey: "update") as? Data,
                      let round = object.value(forKey: "round") as? Int else {
                    return nil
                }
                let id = object.value(forKey: "id") as? Int64 ?? 0
                return (id, update, round)
            }
        } catch {
            print("Get unsynced FL updates error: \(error)")
            return []
        }
    }
    
    func markFLUpdateSynced(id: Int64) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FLUpdates")
        fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            results.first?.setValue(true, forKey: "synced")
            try context.save()
        } catch {
            print("Mark FL update synced error: \(error)")
        }
    }
    
    // MARK: - ModelVersion Operations
    
    func saveModelVersion(version: Int, modelPath: String) {
        // Delete existing
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ModelVersion")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            
            // Insert new
            let model = NSEntityDescription.insertNewObject(forEntityName: "ModelVersion", into: context)
            model.setValue(version, forKey: "version")
            model.setValue(modelPath, forKey: "modelPath")
            try context.save()
        } catch {
            print("Save model version error: \(error)")
        }
    }
    
    func getCurrentModelVersion() -> (version: Int, modelPath: String)? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ModelVersion")
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "version", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            if let model = results.first,
               let version = model.value(forKey: "version") as? Int,
               let modelPath = model.value(forKey: "modelPath") as? String {
                return (version, modelPath)
            }
        } catch {
            print("Get model version error: \(error)")
        }
        return nil
    }
}
