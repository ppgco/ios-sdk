import Foundation
import UIKit

/// Interface for requesting push notification subscription.
/// This provides a clean way for the in-app messages to trigger a subscription request
/// without directly depending on the push notification SDK.
public protocol PushNotificationSubscriber {
    /// Request user to subscribe to push notifications
    ///
    /// - Parameter viewController: The view controller to present permission dialogs
    /// - Returns: true if the subscription request was successfully initiated
    func requestSubscription(viewController: UIViewController) async -> Bool
}

@objc public protocol PushNotificationSubscriberObjC {
    @objc func requestSubscription(
        withViewController viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    )
}

internal final class PushNotificationSubscriberObjCAdapter: PushNotificationSubscriber {
    private weak var subscriber: PushNotificationSubscriberObjC?

    init(_ subscriber: PushNotificationSubscriberObjC) {
        self.subscriber = subscriber
    }

    func requestSubscription(viewController: UIViewController) async -> Bool {
        await withCheckedContinuation { continuation in
            subscriber?.requestSubscription(
                withViewController: viewController,
                completion: { result in
                    continuation.resume(returning: result)
                }
            )
        }
    }
}

/// Utility class for accessing push notification subscription state
/// from the PushPushGo SDK's UserDefaults.
/// 
/// This provides a bridge to the push notification SDK without creating a direct dependency.
internal class PushNotificationStatusProvider {
    
    // Constants
    private static let tag = "PushNotificationStatusProvider"
    
    // These constants match the ones in PushPushGo SDK's UserDefaults
    private static let isSubscribed = "_PushPushGoSDK_is_subscribed_"
    private static let areNotificationsBlocked = "_PushPushGoSDK_notifications_blocked_"
    
    // Properties
    private let userDefaults: UserDefaults
    
    // Initialization
    init() {
        self.userDefaults = UserDefaults.standard
    }
    
    // Public Methods
    
    /// Checks if the user is currently subscribed to push notifications
    /// by reading directly from the PushPushGo SDK's UserDefaults
    /// 
    /// - Returns: true if subscribed (defaults to false if not found)
    func isSubscribed() -> Bool {
        let result = userDefaults.bool(forKey: Self.isSubscribed)
        return result
    }
    
    /// Checks if notifications are blocked for the current user
    /// 
    /// - Returns: true if notifications are blocked (defaults to false if not found)
    func isNotificationsBlocked() -> Bool {
        return userDefaults.bool(forKey: Self.areNotificationsBlocked)
    }
    
    /// Utility method to check if a user matches the given audience type
    /// 
    /// - Parameter audienceType: The audience type to check against
    /// - Returns: true if the current user matches the specified audience type
    func matchesAudienceType(_ audienceType: UserAudienceType) -> Bool {
        switch audienceType {
        case .all:
            return true
        case .subscriber:
            return isSubscribed() && !isNotificationsBlocked()
        case .nonSubscriber:
            return !isSubscribed() || isNotificationsBlocked()
        case .notificationsBlocked:
            return isNotificationsBlocked()
        }
    }
}

/// NotificationCenter-based implementation that communicates with Push SDK
/// without direct dependencies. Uses notification pattern for loose coupling.
internal class DefaultPushNotificationSubscriber: PushNotificationSubscriber {
    
    private static let tag = "DefaultPushSubscriber"
    
    init() {}
    
    func requestSubscription(viewController: UIViewController) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Track if continuation has been resumed to prevent double resume
            var hasResumed = false
            let resumeLock = NSLock()
            
            // Create observer for response
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PPGSubscriptionResult"),
                object: nil,
                queue: .main
            ) { notification in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else { return }
                hasResumed = true
                
                // Clean up observer
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                // Get result from notification
                let success = notification.userInfo?["success"] as? Bool ?? false
                InAppLogger.shared.debug("Subscription result: \(success)")
                continuation.resume(returning: success)
            }
            
            // Set timeout in case no response comes
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else { return }
                hasResumed = true
                
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                InAppLogger.shared.error("Subscription request timeout")
                continuation.resume(returning: false)
            }
            
            // Send subscription request via NotificationCenter
            let userInfo: [String: Any] = ["viewController": viewController]
            NotificationCenter.default.post(
                name: NSNotification.Name("PPGSubscriptionRequest"),
                object: nil,
                userInfo: userInfo
            )
            
            InAppLogger.shared.debug("Subscription request sent")
        }
    }
}
