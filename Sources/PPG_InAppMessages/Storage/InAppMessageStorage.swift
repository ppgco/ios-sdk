import Foundation

/// Storage manager for In-App Messages
public class InAppMessageStorage {
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Storage keys
    private enum StorageKeys {
        static let shownMessages = "ppg_inapp_shown_messages"
        static let lastSync = "ppg_inapp_last_sync"
        static let messageSettings = "ppg_inapp_settings"
        static let displayStats = "ppg_inapp_display_stats"
    }
    
    public init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("PPGInAppMessages")
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Message Tracking
    
    /// Track that a message was shown
    public func markMessageAsShown(_ messageId: String, at date: Date = Date()) {
        var shownMessages = getShownMessages()
        shownMessages[messageId] = date
        saveShownMessages(shownMessages)
    }
    
    /// Check if message was already shown
    public func wasMessageShown(_ messageId: String) -> Bool {
        return getShownMessages().keys.contains(messageId)
    }
    
    /// Get date when message was shown (if any)
    public func getMessageShownDate(_ messageId: String) -> Date? {
        return getShownMessages()[messageId]
    }
    
    /// Get all shown messages
    private func getShownMessages() -> [String: Date] {
        guard let data = userDefaults.data(forKey: StorageKeys.shownMessages),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    /// Save shown messages
    private func saveShownMessages(_ messages: [String: Date]) {
        if let encoded = try? JSONEncoder().encode(messages) {
            userDefaults.set(encoded, forKey: StorageKeys.shownMessages)
        }
    }
    
    // MARK: - Display Statistics
    
    /// Record message display event
    public func recordDisplayEvent(messageId: String, event: String, timestamp: Date = Date()) {
        var stats = getDisplayStats()
        if stats[messageId] == nil {
            stats[messageId] = []
        }
        
        let eventRecord = DisplayEventRecord(event: event, timestamp: timestamp)
        stats[messageId]?.append(eventRecord)
        
        // Keep only last 50 events per message to prevent unlimited growth
        if let events = stats[messageId], events.count > 50 {
            stats[messageId] = Array(events.suffix(50))
        }
        
        saveDisplayStats(stats)
    }
    
    /// Get display statistics for message
    public func getDisplayEvents(for messageId: String) -> [DisplayEventRecord] {
        return getDisplayStats()[messageId] ?? []
    }
    
    /// Get all display statistics
    private func getDisplayStats() -> [String: [DisplayEventRecord]] {
        guard let data = userDefaults.data(forKey: StorageKeys.displayStats),
              let decoded = try? JSONDecoder().decode([String: [DisplayEventRecord]].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    /// Save display statistics
    private func saveDisplayStats(_ stats: [String: [DisplayEventRecord]]) {
        if let encoded = try? JSONEncoder().encode(stats) {
            userDefaults.set(encoded, forKey: StorageKeys.displayStats)
        }
    }
    
    // MARK: - Message Caching
    
    /// Cache message data to disk
    public func cacheMessage(_ message: InAppMessage) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(message.id).json")
        
        do {
            let data = try JSONEncoder().encode(message)
            try data.write(to: cacheFile)
        } catch {
            InAppLogger.shared.error("Failed to cache message \(message.id): \(error)")
        }
    }
    
    /// Load cached message
    public func loadCachedMessage(_ messageId: String) -> InAppMessage? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(messageId).json")
        
        do {
            let data = try Data(contentsOf: cacheFile)
            return try JSONDecoder().decode(InAppMessage.self, from: data)
        } catch {
            InAppLogger.shared.debug("Failed to load cached message \(messageId): \(error)")
            return nil
        }
    }
    
    /// Remove cached message
    public func removeCachedMessage(_ messageId: String) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(messageId).json")
        try? fileManager.removeItem(at: cacheFile)
    }
    
    /// Get all cached message IDs
    public func getCachedMessageIds() -> [String] {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                          includingPropertiesForKeys: nil)
            return files.compactMap { url in
                let filename = url.lastPathComponent
                return filename.hasSuffix(".json") ? String(filename.dropLast(5)) : nil
            }
        } catch {
            return []
        }
    }
    
    // MARK: - Settings Storage
    
    /// Save last sync timestamp
    public func setLastSyncTimestamp(_ timestamp: Date) {
        userDefaults.set(timestamp, forKey: StorageKeys.lastSync)
    }
    
    /// Get last sync timestamp
    public func getLastSyncTimestamp() -> Date? {
        return userDefaults.object(forKey: StorageKeys.lastSync) as? Date
    }
    
    /// Save storage settings
    public func saveStorageSettings(_ settings: StorageSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: StorageKeys.messageSettings)
        }
    }
    
    /// Load storage settings
    public func loadStorageSettings() -> StorageSettings? {
        guard let data = userDefaults.data(forKey: StorageKeys.messageSettings),
              let settings = try? JSONDecoder().decode(StorageSettings.self, from: data) else {
            return nil
        }
        return settings
    }
    
    // MARK: - Cleanup
    
    /// Clean up old data
    public func cleanup() {
        cleanupOldDisplayStats()
        cleanupOldCachedMessages()
        cleanupOldShownMessages()
    }
    
    /// Remove display stats older than 30 days
    private func cleanupOldDisplayStats() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var stats = getDisplayStats()
        var hasChanges = false
        
        for messageId in stats.keys {
            if let events = stats[messageId] {
                let recentEvents = events.filter { $0.timestamp >= cutoffDate }
                if recentEvents.count != events.count {
                    stats[messageId] = recentEvents
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            saveDisplayStats(stats)
        }
    }
    
    /// Remove cached messages older than 7 days
    private func cleanupOldCachedMessages() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory,
                                                          includingPropertiesForKeys: [.contentModificationDateKey])
            
            for file in files {
                if let modificationDate = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            InAppLogger.shared.error("Failed to cleanup old cached messages: \(error)")
        }
    }
    
    /// Remove shown message records older than 90 days
    private func cleanupOldShownMessages() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let shownMessages = getShownMessages()
        let recentMessages = shownMessages.filter { $0.value >= cutoffDate }
        
        if recentMessages.count != shownMessages.count {
            saveShownMessages(recentMessages)
        }
    }
    
    // MARK: - Clear All Data
    
    /// Clear all stored data (for testing or reset)
    public func clearAllData() {
        userDefaults.removeObject(forKey: StorageKeys.shownMessages)
        userDefaults.removeObject(forKey: StorageKeys.lastSync)
        userDefaults.removeObject(forKey: StorageKeys.messageSettings)
        userDefaults.removeObject(forKey: StorageKeys.displayStats)
        
        // Remove all cached files
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory,
                                                          includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            InAppLogger.shared.error("Failed to clear cached files: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Record of a display event
public struct DisplayEventRecord: Codable {
    public let event: String
    public let timestamp: Date
    
    public init(event: String, timestamp: Date) {
        self.event = event
        self.timestamp = timestamp
    }
}

/// Storage settings for InAppMessageStorage
public struct StorageSettings: Codable {
    public let globalEnabled: Bool
    public let debug: Bool
    public let syncInterval: TimeInterval
    public let maxCachedMessages: Int
    
    public init(globalEnabled: Bool = true,
                debug: Bool = false,
                syncInterval: TimeInterval = 300, // 5 minutes
                maxCachedMessages: Int = 50) {
        self.globalEnabled = globalEnabled
        self.debug = debug
        self.syncInterval = syncInterval
        self.maxCachedMessages = maxCachedMessages
    }
}
