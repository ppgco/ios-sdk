import Foundation
import UIKit

/// Manages the lifecycle and business logic of in-app messages
public class InAppMessageManager {
    
    // Properties
    private let repository: InAppMessageRepository
    private let statusProvider = PushNotificationStatusProvider()
    private weak var displayer: InAppMessageDisplayer?
    
    // Current message state
    private var currentlyDisplayedMessage: InAppMessage?
    
    // Display history for "show again" logic - now with timestamps
    private var displayHistory: [String: TimeInterval] = [:]
    private let displayHistoryKey = "InAppMessageDisplayHistory"
    
    // Current route for route-based display filtering
    private var currentRoute: String = ""
    
    // Initialization
    public init(repository: InAppMessageRepository, displayer: InAppMessageDisplayer? = nil) {
        self.repository = repository
        self.displayer = displayer
        loadDisplayHistory()
    }
    
    /// Set displayer reference after initialization
    public func setDisplayer(_ displayer: InAppMessageDisplayer) {
        self.displayer = displayer
    }
    
    /// Set handler for custom code actions from in-app message buttons
    /// This allows the app to handle custom code calls from action buttons
    /// - Parameter handler: Function that takes custom code string and processes it
    public func setCustomCodeActionHandler(_ handler: @escaping (String) -> Void) {
        displayer?.setCustomCodeActionHandler(handler)
    }
    
    // Public Methods
    
    /// Process fetched messages and display eligible ones
    /// - Parameters:
    ///   - messages: Array of messages from API
    ///   - viewController: Current view controller for display
    ///   - skipTriggerCheck: Skip trigger type validation (for custom triggers)
    public func processMessages(_ messages: [InAppMessage], viewController: UIViewController, skipTriggerCheck: Bool = false) async {
        InAppLogger.shared.debug("Processing \(messages.count) messages")
        
        guard currentlyDisplayedMessage == nil else {
            InAppLogger.shared.debug("Message already displayed, skipping")
            return
        }
        
        // Filter messages based on eligibility criteria
        let eligibleMessages = await filterEligibleMessages(messages, skipTriggerCheck: skipTriggerCheck)
        
        // Sort by priority (1 = highest, 2 = second, etc., 0 = lowest)
        let sortedMessages = eligibleMessages.sorted { left, right in
            let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
            let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
            return leftPriority < rightPriority
        }
        
        if let message = sortedMessages.first {
            await displayMessage(message, viewController: viewController)
        } else {
            InAppLogger.shared.debug("No eligible messages to display")
        }
    }
    
    /// Handle custom trigger events with key-value matching
    /// - Parameters:
    ///   - key: Custom trigger key to match
    ///   - value: Custom trigger value to match  
    ///   - viewController: Current view controller
    public func handleCustomTrigger(key: String, value: String, viewController: UIViewController) async {
        InAppLogger.shared.debug("Custom trigger: key='\(key)', value='\(value)'")
        
        do {
            let messages = try await repository.getMessages()
            
            let customTriggerMessages = messages.filter { message in
                // Check if message has custom trigger type
                guard message.matchesTrigger(.custom) else { 
                    return false 
                }
                
                // Key-Value matching logic: both key AND value must match
                if let customKey = message.settings.customTriggerKey,
                   let customValue = message.settings.customTriggerValue {
                    return customKey == key && customValue == value
                } else {
                    return false
                }
            }
            
            // Sort by priority (1 = highest, 2 = second, etc., 0 = lowest)
            let sortedMessages = customTriggerMessages.sorted { left, right in
                let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
                let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
                return leftPriority < rightPriority
            }
            
            InAppLogger.shared.debug("Found \(customTriggerMessages.count) matching messages for custom trigger")
            if !sortedMessages.isEmpty {
                await processMessages(sortedMessages, viewController: viewController, skipTriggerCheck: true)
            }
            
        } catch {
            InAppLogger.shared.error("Failed to handle custom trigger: \(error.localizedDescription)")
        }
    }
    
    /// Mark message as displayed to track history with timestamp
    /// - Parameter messageId: ID of the displayed message
    public func markMessageAsDisplayed(_ messageId: String) {
        let currentTime = Date().timeIntervalSince1970
        displayHistory[messageId] = currentTime
        saveDisplayHistory()
        InAppLogger.shared.debug("Message \(messageId) marked as displayed")
    }
    
    /// Clear currently displayed message
    public func clearCurrentMessage() {
        currentlyDisplayedMessage = nil
    }
    
    /// Set current route for route-based display filtering
    /// - Parameter route: Current route path
    public func setCurrentRoute(_ route: String) {
        currentRoute = route
        InAppLogger.shared.debug("Manager: Current route set to '\(route)'")
    }
    
    /// Public method to check if message should be displayed on specific route
    /// Used by SDK to avoid code duplication
    /// - Parameters:
    ///   - message: Message to check
    ///   - route: Route path to check against
    /// - Returns: True if message should be displayed on the route
    public func shouldDisplayMessageOnRoute(_ message: InAppMessage, route: String) -> Bool {
        let display = message.settings.display
        let displayOn = message.settings.displayOn
        
        // If display is "all", show on every route
        if display.lowercased() == "all" {
            return true
        }
        
        // If display is "selected", check displayOn array
        if display.lowercased() == "selected" {
            // Check if current route is explicitly configured
            for routeConfig in displayOn {
                if routeConfig.path == route {
                    // Found exact route match - return its display setting
                    return routeConfig.display
                }
            }
            
            // Route not found in displayOn array
            // Determine mode: if ANY route has display=true, it's "show mode" (whitelist)
            // Otherwise it's "hide mode" (blacklist)
            let isShowMode = displayOn.contains { $0.display == true }
            
            if isShowMode {
                // Show mode: only show on specified routes
                return false
            } else {
                // Hide mode: hide only on specified routes, show everywhere else
                return true
            }
        }
        
        return true
    }
    
    // Private Methods
    
    /// Filter messages based on eligibility criteria
    /// - Parameter messages: Raw messages from API
    /// - Parameter skipTriggerCheck: Skip trigger type validation (for custom triggers)
    /// - Returns: Filtered eligible messages
    private func filterEligibleMessages(_ messages: [InAppMessage], skipTriggerCheck: Bool = false) async -> [InAppMessage] {
        return messages.filter { message in
            // Don't show message that's already being displayed
            if let currentlyDisplayed = currentlyDisplayedMessage,
               currentlyDisplayed.id == message.id {
                return false
            }
            
            // Check if message is enabled
            guard message.enabled else {
                InAppLogger.shared.debug("Message \(message.id) is disabled")
                return false
            }
            
            // Check audience targeting
            guard message.matchesAudience(provider: statusProvider) else {
                InAppLogger.shared.debug("Message \(message.id) doesn't match audience")
                return false
            }
            
            // Check platform targeting
            guard message.matchesPlatform() else {
                InAppLogger.shared.debug("Message \(message.id) doesn't match platform")
                return false
            }
            
            // Check device targeting - iOS should show for ALL or MOBILE devices
            guard message.matchesDevice() else {
                InAppLogger.shared.debug("Message \(message.id) doesn't match device")
                return false
            }
            
            // Check OS type targeting - iOS should show for ALL or IOS
            guard message.matchesOSType() else {
                InAppLogger.shared.debug("Message \(message.id) doesn't match OS type")
                return false
            }
            
            // Check display history for "show again" logic
            if let lastDisplayTime = displayHistory[message.id] {
                let showAgain = message.settings.showAgain.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if showAgain == "NEVER" {
                    InAppLogger.shared.debug("Message \(message.id) already shown (NEVER show again)")
                    return false
                } else if showAgain == "AFTER_TIME" {
                    let showAfterTimeSeconds = TimeInterval(message.settings.showAfterTime)
                    let currentTime = Date().timeIntervalSince1970
                    let timeSinceLastDisplay = currentTime - lastDisplayTime
                    
                    if timeSinceLastDisplay < showAfterTimeSeconds {
                        InAppLogger.shared.debug("Message \(message.id) shown recently, waiting \(Int(showAfterTimeSeconds - timeSinceLastDisplay))s more")
                        return false
                    }
                }
            }
            
            let shouldDisplayOnCurrentRoute = shouldDisplayMessageOnRoute(message, route: currentRoute)
            if !shouldDisplayOnCurrentRoute {
                InAppLogger.shared.debug("Message \(message.id) not allowed on route '\(currentRoute)'")
                return false
            }
            
            // Check if message should be shown on current trigger
            if skipTriggerCheck {
                return true
            }
            
            // For normal flow, focus on ENTER trigger type
            if message.matchesTrigger(.enter) {
                return true
            }
            
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
            InAppLogger.shared.error("No displayer available")
            return
        }
        
        // Apply showAfterDelay if specified
        let delaySeconds = message.settings.showAfterDelay
        if delaySeconds > 0 {
            InAppLogger.shared.debug("Delaying message by \(delaySeconds)s")
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        }
        
        DispatchQueue.main.async {
            displayer.showMessage(message, in: viewController)
        }
        
        // Mark as displayed with timestamp
        markMessageAsDisplayed(message.id)
    }
    
    // Persistence
    
    /// Load display history from UserDefaults
    private func loadDisplayHistory() {
        if let historyData = UserDefaults.standard.data(forKey: displayHistoryKey),
           let history = try? JSONDecoder().decode([String: TimeInterval].self, from: historyData) {
            displayHistory = history
        }
    }
    
    /// Save display history to UserDefaults
    private func saveDisplayHistory() {
        if let historyData = try? JSONEncoder().encode(displayHistory) {
            UserDefaults.standard.set(historyData, forKey: displayHistoryKey)
        }
    }
}
