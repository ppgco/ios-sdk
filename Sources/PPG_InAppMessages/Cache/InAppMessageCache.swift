import Foundation

/// Cache management for In-App Messages with ETag support
internal class InAppMessageCache {
    
    // Constants
    private enum Keys {
        static let etag = "inappmessages_etag"
        static let cachedMessages = "inappmessages_cached_messages"
        static let cacheTimestamp = "inappmessages_cache_timestamp"
    }
    
    // Cache expiry - after 24h force refresh even with same ETag
    private static let cacheExpiryMs: TimeInterval = 24 * 60 * 60 * 1000 // 24 hours in milliseconds
    
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    // Tag Cache Management
    
    /// Get stored ETag if cache is not expired
    /// - Returns: Stored ETag or nil if expired/not found
    func getStoredETag() -> String? {
        let timestamp = userDefaults.double(forKey: Keys.cacheTimestamp)
        let currentTime = Date().timeIntervalSince1970 * 1000 // Convert to milliseconds
        let timeDiff = currentTime - timestamp
        let isExpired = timestamp > 0 && timeDiff > Self.cacheExpiryMs
        
        if isExpired {
            // Cache expired - clear and return nil to force fresh fetch
            InAppLogger.shared.debug("Cache expired, clearing")
            clearCache()
            return nil
        } else if timestamp == 0 {
            return nil
        } else {
            let storedETag = userDefaults.string(forKey: Keys.etag)
            return storedETag
        }
    }
    
    /// Save ETag and messages to cache
    /// - Parameters:
    ///   - etag: ETag from server response
    ///   - messages: Messages to cache
    func saveCache(etag: String, messages: [InAppMessage]) {
        do {
            let messagesData = try encoder.encode(messages)
            let currentTime = Date().timeIntervalSince1970 * 1000 // Convert to milliseconds
            
            userDefaults.set(etag, forKey: Keys.etag)
            userDefaults.set(messagesData, forKey: Keys.cachedMessages)
            userDefaults.set(currentTime, forKey: Keys.cacheTimestamp)
            
            InAppLogger.shared.debug("Saved \(messages.count) messages to cache")
            
        } catch {
            InAppLogger.shared.error("Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    /// Get cached messages if available
    /// - Returns: Cached messages or nil if not found/invalid
    func getCachedMessages() -> [InAppMessage]? {
        guard let messagesData = userDefaults.data(forKey: Keys.cachedMessages) else {
            return nil
        }
        
        do {
            let messages = try decoder.decode([InAppMessage].self, from: messagesData)
            return messages
        } catch {
            // JSON parsing failed - clear cache and return nil
            InAppLogger.shared.error("Failed to decode cache: \(error.localizedDescription)")
            clearCache()
            return nil
        }
    }
    
    /// Clear all cached data
    func clearCache() {
        userDefaults.removeObject(forKey: Keys.etag)
        userDefaults.removeObject(forKey: Keys.cachedMessages)
        userDefaults.removeObject(forKey: Keys.cacheTimestamp)
    }
    
    // Debug Helpers
    
    /// Get cache status for debugging
    func getCacheStatus() -> (etag: String?, messageCount: Int?, timestamp: Date?, isExpired: Bool) {
        let etag = userDefaults.string(forKey: Keys.etag)
        let timestamp = userDefaults.double(forKey: Keys.cacheTimestamp)
        let timestampDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp / 1000) : nil
        let messageCount = getCachedMessages()?.count
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let isExpired = timestamp > 0 ? (currentTime - timestamp) > Self.cacheExpiryMs : true
        
        return (etag: etag, messageCount: messageCount, timestamp: timestampDate, isExpired: isExpired)
    }
}
