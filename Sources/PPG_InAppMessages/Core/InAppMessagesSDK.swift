// InAppMessagesSDK.swift
// iOS equivalent of InAppMessagesSDK.kt
// Reference: Android InAppMessagesSDK.kt lines 1-150

import Foundation
import UIKit

@objc public class InAppMessagesSDK: NSObject {
    
    // MARK: - Singleton
    @objc public static let shared = InAppMessagesSDK()
    
    // MARK: - Properties
    private var isInitialized = false
    private var apiKey: String?
    private var projectId: String?
    private var userId: String?
    
    // Core components - equivalent to Android components
    private var messageManager: InAppMessageManager?
    private var messageDisplayer: InAppMessageDisplayer?
    private var repository: InAppMessageRepository?
    
    // Bridge to push SDK - equivalent to Android bridge pattern
    private var subscriptionHandler: PushNotificationSubscriber = DefaultPushNotificationSubscriber()
    
    // Background queue for SDK operations - equivalent to Android sdkScope
    private let sdkQueue = DispatchQueue(label: "InAppMessagesSDK", qos: .background)
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// Initialize the SDK with API credentials
    /// Reference: Android initialize() method
    @objc public func initialize(apiKey: String, projectId: String, isProduction: Bool = true) {
        guard !isInitialized else {
            InAppLogger.shared.info("InAppMessagesSDK already initialized")
            return
        }
        
        self.apiKey = apiKey
        self.projectId = projectId
        
        // Initialize core components - equivalent to Android initialization
        self.repository = InAppMessageRepository(apiKey: apiKey, projectId: projectId, isProduction: isProduction)
        self.messageDisplayer = InAppMessageDisplayer(
            onMessageDismissed: { [weak self] in
                self?.onMessageDismissed()
            },
            onMessageEvent: { [weak self] eventType, message, ctaIndex in
                self?.onMessageEvent(eventType, message, ctaIndex)
            },
            subscriptionHandler: subscriptionHandler
        )
        self.messageManager = InAppMessageManager(repository: repository!, displayer: messageDisplayer!)
        
        // Connect manager to displayer
        messageManager?.setDisplayer(messageDisplayer!)
        
        self.isInitialized = true
        InAppLogger.shared.info("InAppMessagesSDK initialized successfully")
    }
    
    /// Set user ID for message targeting
    /// Reference: Android setUserId() method
    @objc public func setUserId(_ userId: String) {
        self.userId = userId
        InAppLogger.shared.info("User ID set: \(userId)")
    }
    
    /// Handle view controller lifecycle - equivalent to Android onActivityResumed
    @objc public func onViewControllerWillAppear(_ viewController: UIViewController) {
        guard isInitialized else {
            InAppLogger.shared.error("SDK not initialized")
            return
        }
        
        // Add delay to prevent collision with system permission dialogs
        // Reference: Android fix for permission dialog collision
        Task {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await refreshActiveMessages(viewController: viewController)
        }
    }
    
    /// Handle view controller disappear
    @objc public func onViewControllerDidDisappear() {
        // Clean up any displayed messages if needed
        messageDisplayer?.dismissMessageSilently()
    }
    
    /// Manually refresh and display eligible messages
    /// Reference: Android refreshActiveMessages() method
    @objc public func refreshActiveMessages(viewController: UIViewController) async {
        guard isInitialized else {
            InAppLogger.shared.error("SDK not initialized")
            return
        }
        
        do {
            // Fetch messages from API
            let messages = try await repository?.getMessages(userId: userId ?? "") ?? []
            InAppLogger.shared.info("SDK received \(messages.count) messages from repository")
            
            // Debug: Log message IDs
            for message in messages {
                InAppLogger.shared.debug("SDK has message: \(message.id)")
            }
            
            // Filter and display eligible messages
            await messageManager?.processMessages(messages, viewController: viewController)
            
        } catch {
            InAppLogger.shared.error("Failed to refresh messages: \(error)")
        }
    }
    
    /// Trigger custom event for message display
    /// Reference: Android custom trigger handling
    @objc public func triggerCustomEvent(_ eventName: String, viewController: UIViewController) {
        Task {
            await messageManager?.handleCustomTrigger(eventName, viewController: viewController)
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle message dismissal - equivalent to Android onMessageDismissed
    private func onMessageDismissed() {
        // Refresh messages after dismissal
        // Implementation depends on current view controller context
        InAppLogger.shared.info("Message dismissed")
    }
    
    /// Handle message events - equivalent to Android onMessageEvent
    /// Reference: Android event dispatch logic with CRITICAL FIX
    private func onMessageEvent(_ eventType: String, _ message: InAppMessage, _ ctaIndex: Int?) {
        Task {
            do {
                switch eventType {
                case "show":
                    try await repository?.dispatchEvent("inapp.show", messageId: message.id)
                case "close":
                    try await repository?.dispatchEvent("inapp.close", messageId: message.id)
                case "cta":
                    // CRITICAL FIX: Button clicks should only send CTA events, not close events
                    if let index = ctaIndex {
                        try await repository?.dispatchEvent("inapp.cta.\(index)", messageId: message.id)
                    }
                default:
                    InAppLogger.shared.error("Unknown event type: \(eventType)")
                }
            } catch {
                InAppLogger.shared.error("Failed to dispatch event: \(error)")
            }
        }
    }
}
