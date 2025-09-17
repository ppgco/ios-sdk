// InAppMessageManager.swift
// iOS equivalent of Android InAppMessageManager.kt
// Reference: Android InAppMessageManager business logic and lifecycle management

import Foundation
import UIKit

/// Manages the lifecycle and business logic of in-app messages
/// Reference: Android InAppMessageManager pattern
public class InAppMessageManager {
    
    // MARK: - Properties
    private let repository: InAppMessageRepository
    private let statusProvider = PushNotificationStatusProvider()
    private weak var displayer: InAppMessageDisplayer?
    
    // Current message state
    private var currentlyDisplayedMessage: InAppMessage?
    
    // Display history for "show again" logic
    private var displayHistory: Set<String> = []
    private let displayHistoryKey = "InAppMessagesDisplayHistory"
    
    // MARK: - Initialization
    public init(repository: InAppMessageRepository, displayer: InAppMessageDisplayer? = nil) {
        self.repository = repository
        self.displayer = displayer
        loadDisplayHistory()
    }
    
    /// Set displayer reference after initialization
    public func setDisplayer(_ displayer: InAppMessageDisplayer) {
        self.displayer = displayer
    }
    
    // MARK: - Public Methods
    
    /// Process fetched messages and display eligible ones
    /// Reference: Android processMessages() method with CRITICAL FIX for audience type logic
    /// - Parameters:
    ///   - messages: Array of messages from API
    ///   - viewController: Current view controller for display
    public func processMessages(_ messages: [InAppMessage], viewController: UIViewController) async {
        InAppLogger.shared.info("🔍 processMessages called with \(messages.count) messages")
        
        guard currentlyDisplayedMessage == nil else {
            InAppLogger.shared.info("Message already displayed, skipping processing")
            return
        }
        
        // Filter messages based on eligibility criteria
        let eligibleMessages = await filterEligibleMessages(messages)
        
        if let message = eligibleMessages.first {
            await displayMessage(message, viewController: viewController)
        } else {
            InAppLogger.shared.info("No eligible messages to display")
        }
    }
    
    /// Handle custom trigger events
    /// Reference: Android handleCustomTrigger() method with improved custom trigger matching
    /// - Parameters:
    ///   - eventName: Custom event name
    ///   - viewController: Current view controller
    public func handleCustomTrigger(_ eventName: String, viewController: UIViewController) async {
        do {
            let messages = try await repository.getMessages(userId: "")
            let customTriggerMessages = messages.filter { message in
                // Check if message has custom trigger type
                guard message.matchesTrigger(.custom) else { return false }
                
                // New logic: use customTriggerKey and customTriggerValue for matching
                if let customKey = message.settings.customTriggerKey,
                   let customValue = message.settings.customTriggerValue {
                    // Match based on custom key-value pair
                    return customKey == eventName || customValue == eventName
                } else {
                    // Fallback to old logic using display field
                    return message.settings.display == eventName
                }
            }
            
            // Sort by priority (1 = highest, 2 = second, etc., 0 = lowest)
            let sortedMessages = customTriggerMessages.sorted { left, right in
                let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
                let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
                return leftPriority < rightPriority
            }
            
            await processMessages(sortedMessages, viewController: viewController)
            
        } catch {
            InAppLogger.shared.error("Failed to handle custom trigger: \(error)")
        }
    }
    
    /// Mark message as displayed to track history
    /// - Parameter messageId: ID of the displayed message
    public func markMessageAsDisplayed(_ messageId: String) {
        displayHistory.insert(messageId)
        saveDisplayHistory()
    }
    
    /// Clear currently displayed message
    public func clearCurrentMessage() {
        currentlyDisplayedMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Filter messages based on eligibility criteria
    /// Reference: Android message filtering logic with CRITICAL FIXES
    /// - Parameter messages: Raw messages from API
    /// - Returns: Filtered eligible messages
    private func filterEligibleMessages(_ messages: [InAppMessage]) async -> [InAppMessage] {
        InAppLogger.shared.info("Filtering \(messages.count) messages")
        
        return messages.filter { message in
            InAppLogger.shared.debug("Processing message \(message.id)")
            
            // Check if message is enabled
            guard message.enabled else {
                InAppLogger.shared.debug("❌ Message \(message.id) is disabled")
                return false
            }
            InAppLogger.shared.debug("✅ Message \(message.id) is enabled")
            
            // CRITICAL FIX: Apply corrected audience type matching logic
            guard message.matchesAudience(provider: statusProvider) else {
                InAppLogger.shared.debug("❌ Message \(message.id) doesn't match audience (userType: \(message.audience.userType))")
                return false
            }
            InAppLogger.shared.debug("✅ Message \(message.id) matches audience")
            
            // Check platform targeting - iOS is considered MOBILE platform
            guard message.matchesPlatform() else {
                InAppLogger.shared.debug("❌ Message \(message.id) doesn't match platform (platform: \(message.audience.platform))")
                return false
            }
            InAppLogger.shared.debug("✅ Message \(message.id) matches platform")
            
            // Check display history for "show again" logic
            if message.settings.showAgain == "never" && displayHistory.contains(message.id) {
                InAppLogger.shared.debug("❌ Message \(message.id) already shown and set to never show again")
                return false
            }
            InAppLogger.shared.debug("✅ Message \(message.id) passed display history check")
            
            // Check if message should be shown on current trigger
            // For now, we'll focus on ENTER trigger type
            InAppLogger.shared.debug("Message \(message.id) trigger type: \(message.settings.triggerType)")
            if message.matchesTrigger(.enter) {
                InAppLogger.shared.debug("✅ Message \(message.id) matches ENTER trigger")
                return true
            }
            
            InAppLogger.shared.debug("❌ Message \(message.id) doesn't match current trigger")
            return false
        }
    }
    
    /// Display a message using the displayer
    /// - Parameters:
    ///   - message: Message to display
    ///   - viewController: View controller to display on
    private func displayMessage(_ message: InAppMessage, viewController: UIViewController) async {
        currentlyDisplayedMessage = message
        
        InAppLogger.shared.info("Displaying message: \(message.id)")
        
        // ACTUALLY display the message using InAppMessageDisplayer
        guard let displayer = displayer else {
            InAppLogger.shared.error("❌ No displayer available - cannot show message")
            return
        }
        
        DispatchQueue.main.async {
            InAppLogger.shared.info("🚀 Showing message on main thread")
            displayer.showMessage(message, in: viewController)
        }
        
        // Mark as displayed after attempting to show
        markMessageAsDisplayed(message.id)
    }
    
    // MARK: - Persistence
    
    /// Load display history from UserDefaults
    private func loadDisplayHistory() {
        if let history = UserDefaults.standard.array(forKey: displayHistoryKey) as? [String] {
            displayHistory = Set(history)
        }
    }
    
    /// Save display history to UserDefaults
    private func saveDisplayHistory() {
        UserDefaults.standard.set(Array(displayHistory), forKey: displayHistoryKey)
    }
}
