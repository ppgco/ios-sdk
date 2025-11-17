import Foundation
import UIKit

@objc public class InAppMessagesSDK: NSObject {
    
    // Singleton
    @objc public static let shared = InAppMessagesSDK()
    
    // Properties
    private var isInitialized = false
    private var apiKey: String?
    private var projectId: String?
    private var repository: InAppMessageRepository?
    private var messageManager: InAppMessageManager?
    private var messageDisplayer: InAppMessageDisplayer?
    
    // Background timer for periodic message checking
    private var backgroundTimer: Timer?
    private weak var currentViewController: UIViewController?
    
    // Route tracking for automatic message display
    private var currentRoute: String = ""
    
    // Bridge to push SDK
    private var subscriptionHandler: PushNotificationSubscriber = DefaultPushNotificationSubscriber()
    
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
        stopBackgroundTimer()
    }
    
    @objc private func appWillEnterForeground() {
        if currentViewController != nil {
            startBackgroundTimer()
        }
    }
    
    // Public API
    
    /// Initialize the SDK with API credentials
    /// - Parameters:
    ///   - apiKey: API key for authentication
    ///   - projectId: Project ID for the app
    ///   - isProduction: Use production or (PPG)test environment (default: true)
    ///   - isDebug: Enable debug logging (default: false)
    @objc public func initialize(apiKey: String, projectId: String, isProduction: Bool = true, isDebug: Bool = false) {
        // Enable/disable debug logging based on parameter
        InAppLogger.shared.setDebugEnabled(isDebug)
        
        guard !isInitialized else {
            InAppLogger.shared.info("InAppMessagesSDK already initialized")
            return
        }
        
        self.apiKey = apiKey
        self.projectId = projectId
        
        // Initialize core components
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
    
    /// Set handler for custom code actions from in-app message buttons
    /// This allows the app to handle custom code calls from action buttons
    /// - Parameter handler: Function that takes custom code string and processes it
    @objc public func setCustomCodeActionHandler(_ handler: @escaping (String) -> Void) {
        messageManager?.setCustomCodeActionHandler(handler)
        InAppLogger.shared.debug("Custom code action handler set")
    }
    
    /// Handle view controller lifecycle
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
    @objc public func refreshActiveMessages(viewController: UIViewController) async {
        guard isInitialized else {
            InAppLogger.shared.error("SDK not initialized")
            return
        }
        
        do {
            // Fetch messages from API
            let messages = try await repository?.getMessages() ?? []
            InAppLogger.shared.debug("Received \(messages.count) messages from API")
            
            // Filter and display eligible messages
            await messageManager?.processMessages(messages, viewController: viewController)
            
        } catch {
            InAppLogger.shared.error("Failed to refresh messages: \(error.localizedDescription)")
        }
    }
    
    /// Show messages on custom trigger with key-value matching
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
                InAppLogger.shared.error("Cannot find view controller for custom trigger")
                return
            }
            
            await messageManager?.handleCustomTrigger(key: key, value: value, viewController: viewController)
        }
    }
    
    /// Notify SDK about route change and check for route-specific messages
    /// The SDK will automatically find the current view controller and display eligible messages
    /// - Parameters:
    ///   - route: New route path (e.g., "home", "product-detail", "checkout")
    @objc public func onRouteChanged(_ route: String) {
        currentRoute = route
        
        // Clear any pending messages from previous route
        messageManager?.clearQueue()
        
        // CRITICAL: Update manager's current route for filtering
        messageManager?.setCurrentRoute(route)
        
        InAppLogger.shared.debug("Route changed to: '\(route)'")
        
        // Try to get view controller - first from stored, then find automatically
        let viewController = currentViewController ?? findCurrentViewController()
        
        guard let viewController = viewController else {
            InAppLogger.shared.error("Cannot display messages - no view controller found")
            return
        }
        
        // Store for future use and start background timer
        currentViewController = viewController
        startBackgroundTimer()
        
        // Refresh and display eligible messages
        Task {
            await refreshActiveMessages(viewController: viewController)
        }
    }
    
    /// Clear message cache (useful for testing or troubleshooting)
    /// This will force fresh data fetch on next API call
    @objc public func clearMessageCache() {
        guard let repository = repository else {
            InAppLogger.shared.debug("Repository not initialized")
            return
        }
        
        repository.clearCache()
        InAppLogger.shared.info("Message cache cleared")
    }
    
    /// Get cache status for debugging (internal use)
    internal func getCacheStatus() -> (etag: String?, messageCount: Int?, timestamp: Date?, isExpired: Bool)? {
        return repository?.getCacheStatus()
    }
    
    // Private Methods
    
    /// Handle message dismissal
    private func onMessageDismissed() {
        // Clear current message from manager to allow new messages
        messageManager?.clearCurrentMessage()
        InAppLogger.shared.debug("Message dismissed")
        
        // NOTE: Do NOT immediately refresh messages here
        // Let only the background timer decide when to check for eligible messages
        // This ensures proper showAfterTime behavior when app is running
    }
    
    // Background Timer
    
    /// Start background timer to check messages every minute
    private func startBackgroundTimer() {
        // Stop existing timer if any
        stopBackgroundTimer()
        
        // Create timer that fires every 60 seconds
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let viewController = self.currentViewController,
                  self.isInitialized else { 
                return 
            }
            
            InAppLogger.shared.debug("Background timer: checking for messages")
            
            Task {
                await self.refreshActiveMessages(viewController: viewController)
            }
        }
        
        InAppLogger.shared.debug("Background timer started (60s interval)")
    }
    
    /// Stop background timer
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
    
    /// Handle message events
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
            return stored
        }
        
        // Strategy 2: Get from key window root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = keyWindow.rootViewController {
            
            let topVC = findTopMostViewController(from: rootViewController)
            return topVC
        }
        
        // Strategy 3: Fallback to first window's root view controller
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController {
            
            let topVC = findTopMostViewController(from: rootViewController)
            return topVC
        }
        
        InAppLogger.shared.error("Could not find view controller")
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
