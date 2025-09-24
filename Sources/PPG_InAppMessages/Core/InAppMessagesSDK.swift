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
    private var repository: InAppMessageRepository?
    private var messageManager: InAppMessageManager?
    private var messageDisplayer: InAppMessageDisplayer?
    private var userId: String = ""
    
    // Background timer for periodic message checking
    private var backgroundTimer: Timer?
    private weak var currentViewController: UIViewController?
    
    // Route tracking for automatic message display
    private var currentRoute: String = ""
    
    // Bridge to push SDK - equivalent to Android bridge pattern
    private var subscriptionHandler: PushNotificationSubscriber = DefaultPushNotificationSubscriber()
    
    // Background queue for SDK operations - equivalent to Android sdkScope
    private let sdkQueue = DispatchQueue(label: "InAppMessagesSDK", qos: .background)
    
    private override init() {
        super.init()
        setupAppLifecycleObservers()
    }
    
    /// Setup app lifecycle observers for proper timer management
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        InAppLogger.shared.info("🌙 App entered background - stopping background timer")
        stopBackgroundTimer()
    }
    
    @objc private func appWillEnterForeground() {
        InAppLogger.shared.info("☀️ App entering foreground - resuming background timer")
        if currentViewController != nil {
            startBackgroundTimer()
        }
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
    
    /// Set handler for JS actions from in-app message buttons
    /// This allows the app to handle custom code calls from action buttons
    /// - Parameter handler: Function that takes JS call string and processes it
    @objc public func setJsActionHandler(_ handler: @escaping (String) -> Void) {
        messageManager?.setJsActionHandler(handler)
        InAppLogger.shared.info("JS action handler set")
    }
    
    /// Handle view controller lifecycle - equivalent to Android onActivityResumed
    @objc public func onViewControllerWillAppear(_ viewController: UIViewController) {
        guard isInitialized else {
            InAppLogger.shared.error("SDK not initialized")
            return
        }
        
        // Store current view controller for background timer
        currentViewController = viewController
        
        // Update manager's current route (if we have one set)
        if !currentRoute.isEmpty {
            messageManager?.setCurrentRoute(currentRoute)
        }
        
        // Start background timer for periodic checking
        startBackgroundTimer()
        
        Task {
            await refreshActiveMessages(viewController: viewController)
        }
    }
    
    /// Handle view controller disappear
    @objc public func onViewControllerDidDisappear() {
        // Clean up any displayed messages if needed
        messageDisplayer?.dismissMessageSilently()
        
        // Stop background timer when view disappears
        stopBackgroundTimer()
        currentViewController = nil
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
    
    /// Show messages on custom trigger with key-value matching
    /// Reference: Android custom trigger handling with key-value pairs
    /// - Parameters:
    ///   - key: Custom trigger key to match
    ///   - value: Custom trigger value to match
    ///   - viewController: View controller to display message on
    @objc public func showMessagesOnTrigger(key: String, value: String, viewController: UIViewController) {
        Task {
            await messageManager?.handleCustomTrigger(key: key, value: value, viewController: viewController)
        }
    }
    
    /// Show messages on custom trigger with automatic view controller discovery
    /// Convenient method for SwiftUI and other contexts where ViewController is not readily available
    /// - Parameters:
    ///   - key: Custom trigger key to match
    ///   - value: Custom trigger value to match
    @objc public func showMessagesOnTrigger(key: String, value: String) {
        Task {
            guard let viewController = findCurrentViewController() else {
                InAppLogger.shared.error("❌ Cannot find current view controller for custom trigger")
                return
            }
            
            await messageManager?.handleCustomTrigger(key: key, value: value, viewController: viewController)
        }
    }
    
    /// Notify SDK about route change and check for route-specific messages
    /// This updates the current route and checks for messages if view controller is available
    /// - Parameters:
    ///   - route: New route path (e.g., "home", "product-detail", "checkout")
    @objc public func onRouteChanged(_ route: String) {
        let previousRoute = currentRoute
        currentRoute = route
        
        // CRITICAL: Update manager's current route for filtering
        messageManager?.setCurrentRoute(route)
        
        InAppLogger.shared.info("🗺️ Route changed: '\(previousRoute)' → '\(route)'")
        
        // Only refresh messages if we have a current view controller
        // This avoids duplication with onViewControllerWillAppear() during app startup
        if let viewController = currentViewController {
            InAppLogger.shared.info("🗺️ Checking messages for new route '\(route)'")
            Task {
                await refreshActiveMessages(viewController: viewController)
            }
        } else {
            InAppLogger.shared.info("🗺️ No current view controller - messages will be checked on next view appear")
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle message dismissal - equivalent to Android onMessageDismissed
    private func onMessageDismissed() {
        // Clear current message from manager to allow new messages
        messageManager?.clearCurrentMessage()
        InAppLogger.shared.info("✅ Message dismissed and cleared - waiting for background timer")
        
        // NOTE: Do NOT immediately refresh messages here
        // Let only the background timer decide when to check for eligible messages
        // This ensures proper showAfterTime behavior when app is running
    }
    
    // MARK: - Background Timer
    
    /// Start background timer to check messages every minute
    private func startBackgroundTimer() {
        // Stop existing timer if any
        stopBackgroundTimer()
        
        // Create timer that fires every 60 seconds
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let viewController = self.currentViewController,
                  self.isInitialized else { 
                InAppLogger.shared.debug("⏰ Background timer: skipping check (not initialized or no VC)")
                return 
            }
            
            InAppLogger.shared.info("⏰ Background timer: checking for eligible messages")
            
            Task {
                await self.refreshActiveMessages(viewController: viewController)
            }
        }
        
        InAppLogger.shared.info("⏰ Background timer started (60s interval)")
    }
    
    /// Stop background timer
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        InAppLogger.shared.info("⏰ Background timer stopped")
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
                    if let index = ctaIndex {
                        let oneBasedIndex = index + 1
                        try await repository?.dispatchEvent("inapp.cta.\(oneBasedIndex)", messageId: message.id)
                    }
                default:
                    InAppLogger.shared.error("Unknown event type: \(eventType)")
                }
            } catch {
                InAppLogger.shared.error("Failed to dispatch event: \(error)")
            }
        }
    }
    
    /// Find current view controller using multiple strategies
    /// - Returns: Current view controller or nil if not found
    private func findCurrentViewController() -> UIViewController? {
        // Strategy 1: Use stored currentViewController if available
        if let stored = currentViewController {
            InAppLogger.shared.debug("Using stored currentViewController")
            return stored
        }
        
        // Strategy 2: Get from key window root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = keyWindow.rootViewController {
            
            let topVC = findTopMostViewController(from: rootViewController)
            InAppLogger.shared.debug("Found view controller from key window: \(type(of: topVC))")
            return topVC
        }
        
        // Strategy 3: Fallback to first window's root view controller
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController {
            
            let topVC = findTopMostViewController(from: rootViewController)
            InAppLogger.shared.debug("Found view controller from first window: \(type(of: topVC))")
            return topVC
        }
        
        InAppLogger.shared.error("❌ Could not find any view controller")
        return nil
    }
    
    /// Find the topmost presented view controller
    /// - Parameter base: Base view controller to search from
    /// - Returns: Topmost view controller
    private func findTopMostViewController(from base: UIViewController) -> UIViewController {
        if let presented = base.presentedViewController {
            return findTopMostViewController(from: presented)
        }
        
        if let navigation = base as? UINavigationController {
            return findTopMostViewController(from: navigation.visibleViewController ?? navigation)
        }
        
        if let tab = base as? UITabBarController {
            return findTopMostViewController(from: tab.selectedViewController ?? tab)
        }
        
        return base
    }
}
