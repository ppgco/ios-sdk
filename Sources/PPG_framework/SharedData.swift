//
//  SharedData.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 14/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

public class SharedData {

    public static var shared = SharedData()
    public var appGroupId: String = ""
    var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }

    var projectId: String {
        get {
            return sharedDefaults?.string(forKey: "PPGProjectId") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGProjectId")
        }
    }

    var apiToken: String {
        get {
            return sharedDefaults?.string(forKey: "PPGAPIToken") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGAPIToken")
        }
    }

    var subscriberId: String {
        get {
            return sharedDefaults?.string(forKey: "PPGSubscriberId")
                // Legacy supported value
                ?? UserDefaults.standard.string(forKey: "PPGSubscriberId") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGSubscriberId")
        }
    }

    var deviceToken: String {
        get {
            return sharedDefaults?.string(forKey: "PPGDeviceToken") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGDeviceToken")
        }
    }

    var eventManager: EventManager {
        return EventManager(sharedData: self)
    }

    var center: UNUserNotificationCenter!
    
    // PPG_InAppMessages bridge section
    // Push Notification Status Management
    // Keys that match PushNotificationStatusProvider in PPG_InAppMessages
    private static let isSubscribedKey = "_PushPushGoSDK_is_subscribed_"
    private static let areNotificationsBlockedKey = "_PushPushGoSDK_notifications_blocked_"
    
    /// Tracks if user is currently subscribed to push notifications
    var isSubscribed: Bool {
        get {
            // Use standard UserDefaults to match PushNotificationStatusProvider
            return UserDefaults.standard.bool(forKey: Self.isSubscribedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.isSubscribedKey)
        }
    }
    
    /// Tracks if notifications are blocked at system level
    var areNotificationsBlocked: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Self.areNotificationsBlockedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.areNotificationsBlockedKey)
        }
    }
    
    /// Update subscription status and check system permissions
    func updateSubscriptionStatus(isSubscribed: Bool) {
        self.isSubscribed = isSubscribed
        
        // Also check current system notification permissions
        checkAndUpdateNotificationPermissions()
    }
    
    /// Check system notification permissions and update blocked status
    func checkAndUpdateNotificationPermissions() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                // User has blocked notifications at system level
                let isBlocked = (settings.authorizationStatus == .denied)
                self?.areNotificationsBlocked = isBlocked
            }
        }
    }
}
