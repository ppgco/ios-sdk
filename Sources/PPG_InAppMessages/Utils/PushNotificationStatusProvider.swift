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

/// Default implementation that attempts to find the PushPushGoSubscriptionManager 
/// in the push notifications SDK using runtime class discovery.
/// 
/// This provides automatic integration between the in-app messages library and 
/// the push notifications SDK without creating direct compile-time dependencies.
/// 
/// Reference: Android DefaultPushNotificationSubscriber
public class DefaultPushNotificationSubscriber: PushNotificationSubscriber {
    
    private static let tag = "DefaultPushSubscriber"
    private static let bridgeClassName = "PushPushGoSubscriptionBridgeManager"
    
    public init() {}
    
    public func requestSubscription(viewController: UIViewController) async -> Bool {
        // Try to find the PushPushGoSubscriptionManager class using runtime discovery
        // Reference: Android reflection-based bridge discovery
        guard let bridgeClass = NSClassFromString(Self.bridgeClassName) as? NSObject.Type else {
            InAppLogger.shared.error("\(Self.tag): \(Self.bridgeClassName) not found. Make sure the push notifications SDK is included")
            return false
        }
        
        do {
            // Create instance of the bridge manager
            let bridgeManager = bridgeClass.init()
            
            // Try to call requestSubscription method using string selector
            // Note: In production, you might want to use a protocol instead of performSelector
            let selectorName = "requestSubscriptionObjC:"
            let selector = NSSelectorFromString(selectorName)
            
            if bridgeManager.responds(to: selector) {
                let unmanagedResult = bridgeManager.perform(selector, with: viewController)
                let result = unmanagedResult?.takeUnretainedValue() as? NSNumber
                return result?.boolValue ?? false
            } else {
                InAppLogger.shared.error("\(Self.tag): requestSubscription method not found on bridge manager")
                return false
            }
            
        } catch {
            InAppLogger.shared.error("\(Self.tag): Error requesting subscription: \(error)")
            return false
        }
    }
}

// MARK: - Objective-C Bridge Helper
// This selector is used for runtime method discovery
@objc protocol PushSubscriptionBridgeObjC {
    @objc func requestSubscriptionObjC(viewController: UIViewController) -> NSNumber
}

// MARK: - UserDefaults Keys Extension
extension UserDefaults {
    /// Convenience methods for accessing PushPushGo SDK state
    /// Reference: Android SharedPreferencesHelper
    
    var pushPushGoIsSubscribed: Bool {
        get { bool(forKey: "_PushPushGoSDK_is_subscribed_") }
        set { set(newValue, forKey: "_PushPushGoSDK_is_subscribed_") }
    }
    
    var pushPushGoNotificationsBlocked: Bool {
        get { bool(forKey: "_PushPushGoSDK_notifications_blocked_") }
        set { set(newValue, forKey: "_PushPushGoSDK_notifications_blocked_") }
    }
}
