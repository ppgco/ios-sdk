// InAppMessageRepository.swift
// iOS equivalent of Android InAppMessageRepository.kt
// Reference: Android InAppMessageRepository.kt and API handling

import Foundation

/// Repository class for handling API communication for in-app messages
/// Reference: Android InAppMessageRepository pattern
public class InAppMessageRepository {
    
    // MARK: - Properties
    private let apiKey: String
    private let projectId: String
    private let isProduction: Bool
    
    private let session: URLSession
    private let cache: InAppMessageCache
    
    // API endpoints - reference Android API configuration
    private var baseURL: String {
        return isProduction ? "https://api.pushpushgo.com" : "https://api.master1.qappg.co"
    }
    
    // MARK: - Initialization
    public init(apiKey: String, projectId: String, isProduction: Bool = true, cache: InAppMessageCache? = nil) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.isProduction = isProduction
        self.session = URLSession.shared
        self.cache = cache ?? InAppMessageCache()
    }
    
    // MARK: - Public Methods
    
    /// Fetch active in-app messages from API with ETag caching
    /// Reference: Android getMessages() method with ETag optimization
    /// - Parameter userId: User ID for message targeting
    /// - Returns: Array of InAppMessage objects
    public func getMessages(userId: String) async throws -> [InAppMessage] {
        // Get stored ETag for cache validation
        let storedETag = cache.getStoredETag()
        
        InAppLogger.shared.debug("Fetching messages (ETag: \(storedETag ?? "none"))")
        
        let baseEndpoint = "\(baseURL)/wi/v1/ios/projects/\(projectId)/popups"
        
        // Add required query parameters
        var urlComponents = URLComponents(string: baseEndpoint)
        urlComponents?.queryItems = [
            URLQueryItem(name: "search", value: ""),
            URLQueryItem(name: "sortBy", value: "newest"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100")
        ]
        
        guard let url = urlComponents?.url else {
            throw RepositoryError.invalidURL
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add ETag header for cache validation
        if let storedETag = storedETag {
            request.setValue(storedETag, forHTTPHeaderField: "If-None-Match")
        }
        
        do {
            // iOS 13+ compatible networking
            let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: RepositoryError.invalidResponse)
                    }
                }.resume()
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RepositoryError.invalidResponse
            }

            // Handle different response codes based on ETag
            switch httpResponse.statusCode {
            case 200:
                // Fresh data received
                let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
                let messages = messagesResponse.data
                
                // Save ETag and cache the payload
                if let newETag = httpResponse.allHeaderFields["Etag"] as? String {
                    cache.saveCache(etag: newETag, messages: messages)
                }
                
                InAppLogger.shared.debug("Fetched \(messages.count) messages from API")
                return messages
                
            case 304:
                // Not Modified - use cached data
                let cachedMessages = cache.getCachedMessages()
                
                if let cachedMessages = cachedMessages {
                    InAppLogger.shared.debug("Using \(cachedMessages.count) cached messages (304)")
                    return cachedMessages
                } else {
                    InAppLogger.shared.debug("304 response but no cache, clearing")
                    cache.clearCache()
                    return []
                }
                
            default:
                InAppLogger.shared.error("API error: HTTP \(httpResponse.statusCode)")
                
                // On error, try to return cached messages if available
                let cachedMessages = cache.getCachedMessages()
                if let cachedMessages = cachedMessages {
                    InAppLogger.shared.debug("Using \(cachedMessages.count) cached messages (fallback)")
                    return cachedMessages
                } else {
                    throw RepositoryError.httpError(httpResponse.statusCode)
                }
            }
            
        } catch {
            InAppLogger.shared.error("Network error: \(error.localizedDescription)")
            
            // On network error, try to return cached messages if available
            let cachedMessages = cache.getCachedMessages()
            if let cachedMessages = cachedMessages {
                InAppLogger.shared.debug("Using \(cachedMessages.count) cached messages (network error)")
                return cachedMessages
            } else {
                throw error
            }
        }
    }
    
    /// Dispatch event to analytics API
    /// Reference: Android dispatchEvent() method with CRITICAL FIX
    /// - Parameters:
    ///   - eventType: Type of event (inapp.show, inapp.close, inapp.cta.X)
    ///   - messageId: ID of the message
    public func dispatchEvent(_ eventType: String, messageId: String) async throws {
        let endpoint = "\(baseURL)/v1/ios/\(projectId)/inapp/event"
        
        guard let url = URL(string: endpoint) else {
            throw RepositoryError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let eventPayload = [
            "action": eventType,
            "inApp": messageId,
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventPayload)
            request.httpBody = jsonData
            
            InAppLogger.shared.debug("Dispatching event: \(eventType) for message: \(messageId)")
            
            // iOS 13+ compatible networking
            let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: RepositoryError.invalidResponse)
                    }
                }.resume()
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RepositoryError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw RepositoryError.httpError(httpResponse.statusCode)
            }
            
            if !data.isEmpty {
                let eventResponse = try JSONDecoder().decode(EventResponse.self, from: data)
                if !eventResponse.success {
                    throw RepositoryError.apiError(eventResponse.error ?? "Event dispatch failed")
                }
            }
            
            InAppLogger.shared.debug("Event dispatched: \(eventType)")
            
        } catch {
            InAppLogger.shared.error("Failed to dispatch event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Clear message cache
    /// This will force fresh data fetch on next API call
    public func clearCache() {
        cache.clearCache()
    }
    
    /// Get cache status for debugging
    /// - Returns: Cache status information
    public func getCacheStatus() -> (etag: String?, messageCount: Int?, timestamp: Date?, isExpired: Bool) {
        return cache.getCacheStatus()
    }
}

// MARK: - Repository Errors
public enum RepositoryError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
