// PushNotificationStatusProvider.swift
// iOS equivalent of Android PushNotificationStatusProvider.kt
// Reference: Android PushNotificationStatusProvider.kt lines 1-65

import Foundation
import UIKit

/// Utility class for accessing push notification subscription state
/// from the PushPushGo SDK's UserDefaults.
/// 
/// This provides a bridge to the push notification SDK without creating a direct dependency.
/// Reference: Android PushNotificationStatusProvider.kt
public class PushNotificationStatusProvider {
    
    // MARK: - Constants
    private static let tag = "PushNotificationStatusProvider"
    
    // These constants match the ones in PushPushGo SDK's UserDefaults
    // Reference: Android SharedPreferencesHelper constants
    private static let isSubscribed = "_PushPushGoSDK_is_subscribed_"
    private static let areNotificationsBlocked = "_PushPushGoSDK_notifications_blocked_"
    
    // MARK: - Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    public init() {
        self.userDefaults = UserDefaults.standard
    }
    
    // MARK: - Public Methods
    
    /// Checks if the user is currently subscribed to push notifications
    /// by reading directly from the PushPushGo SDK's UserDefaults
    /// 
    /// Reference: Android isSubscribed() method
    /// - Returns: true if subscribed (defaults to false if not found)
    public func isSubscribed() -> Bool {
        let result = userDefaults.bool(forKey: Self.isSubscribed)
        InAppLogger.shared.info("\(Self.tag): Checking subscription status: \(result)")
        return result
    }
    
    /// Checks if notifications are blocked for the current user
    /// 
    /// Reference: Android isNotificationsBlocked() method
    /// - Returns: true if notifications are blocked (defaults to false if not found)
    public func isNotificationsBlocked() -> Bool {
        return userDefaults.bool(forKey: Self.areNotificationsBlocked)
    }
    
    /// Utility method to check if a user matches the given audience type
    /// 
    /// Reference: Android matchesAudienceType() method with CRITICAL FIX
    /// - Parameter audienceType: The audience type to check against
    /// - Returns: true if the current user matches the specified audience type
    public func matchesAudienceType(_ audienceType: UserAudienceType) -> Bool {
        switch audienceType {
        case .all:
            return true
        case .subscriber:
            // CRITICAL FIX: Check both subscription status AND notification permissions
            // Reference: Android fix for audience type logic bug
            return isSubscribed() && !isNotificationsBlocked()
        case .nonSubscriber:
            // CRITICAL FIX: Non-subscriber includes users with blocked notifications
            return !isSubscribed() || isNotificationsBlocked()
        case .notificationsBlocked:
            return isNotificationsBlocked()
        }
    }
}

// MARK: - Bridge Protocol
// Reference: Android PushNotificationSubscriber.kt

/// Interface for requesting push notification subscription.
/// This provides a clean way for the in-app messages to trigger a subscription request
/// without directly depending on the push notification SDK.
/// 
/// Reference: Android PushNotificationSubscriber interface
public protocol PushNotificationSubscriber {
    /// Request user to subscribe to push notifications
    /// 
    /// - Parameter viewController: The view controller to present permission dialogs
    /// - Returns: true if the subscription request was successfully initiated
    func requestSubscription(viewController: UIViewController) async -> Bool
}

/// NotificationCenter-based implementation that communicates with Push SDK
/// without direct dependencies. Uses notification pattern for loose coupling.
/// 
/// Reference: Android DefaultPushNotificationSubscriber
public class DefaultPushNotificationSubscriber: PushNotificationSubscriber {
    
    private static let tag = "DefaultPushSubscriber"
    
    public init() {}
    
    public func requestSubscription(viewController: UIViewController) async -> Bool {
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
                InAppLogger.shared.info("\(Self.tag): Received subscription result: \(success)")
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
                InAppLogger.shared.error("\(Self.tag): Subscription request timeout")
                continuation.resume(returning: false)
            }
            
            // Send subscription request via NotificationCenter
            let userInfo: [String: Any] = ["viewController": viewController]
            NotificationCenter.default.post(
                name: NSNotification.Name("PPGSubscriptionRequest"),
                object: nil,
                userInfo: userInfo
            )
            
            InAppLogger.shared.info("\(Self.tag): Subscription request sent via NotificationCenter")
        }
    }
}

// MARK: - Objective-C Bridge Helper
// This selector is used for runtime method discovery
@objc protocol PushSubscriptionBridgeObjC {
    @objc func requestSubscriptionObjC(viewController: UIViewController) -> NSNumber
}

