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
    
    // API endpoints - reference Android API configuration
    private var baseURL: String {
        return isProduction ? "https://api.pushpushgo.com" : "https://api.master1.qappg.co"
    }
    
    // MARK: - Initialization
    public init(apiKey: String, projectId: String, isProduction: Bool = true) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.isProduction = isProduction
        self.session = URLSession.shared
    }
    
    // MARK: - Public Methods
    
    /// Fetch active in-app messages from API
    /// Reference: Android getMessages() method
    /// - Parameter userId: User ID for message targeting
    /// - Returns: Array of InAppMessage objects
    public func getMessages(userId: String) async throws -> [InAppMessage] {
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Optional caching header (can be added later if needed)
        // request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        
        InAppLogger.shared.info("Fetching messages for user: \(userId)")
        
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
            
            guard httpResponse.statusCode == 200 else {
                throw RepositoryError.httpError(httpResponse.statusCode)
            }
            
            let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
            
            InAppLogger.shared.info("Successfully fetched \(messagesResponse.data.count) messages (total: \(messagesResponse.metadata.total))")
            return messagesResponse.data
            
        } catch {
            InAppLogger.shared.error("Failed to fetch messages: \(error)")
            throw error
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
            
            InAppLogger.shared.info("Dispatching event: \(eventType) for message: \(messageId)")
            
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
            
            InAppLogger.shared.info("Successfully dispatched event: \(eventType)")
            
        } catch {
            InAppLogger.shared.error("Failed to dispatch event: \(error)")
            throw error
        }
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
