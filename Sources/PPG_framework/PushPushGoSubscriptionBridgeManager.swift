// PushPushGoSubscriptionBridgeManager.swift
// Bridge class for PPG_InAppMessages to request push notification subscriptions
// This allows In-App Messages to trigger subscription without direct dependencies

import Foundation
import UIKit

/// Bridge manager for handling subscription requests from In-App Messages
/// Uses NotificationCenter pattern for communication without direct dependencies
@objc public class PushPushGoSubscriptionBridgeManager: NSObject {
    
    private static let tag = "PushSubscriptionBridge"
    
    @objc public override init() {
        super.init()
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        // Listen for subscription requests from In-App Messages
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionRequest(_:)),
            name: NSNotification.Name("PPGSubscriptionRequest"),
            object: nil
        )
    }
    
    @objc private func handleSubscriptionRequest(_ notification: Notification) {
        guard notification.userInfo?["viewController"] is UIViewController else {
            sendResult(success: false)
            return
        }
        
        // Get UIApplication.shared safely using reflection
        guard let sharedApplication = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else {
            sendResult(success: false)
            return
        }
        
        // Use existing PPG.registerForNotifications API
        PPG.registerForNotifications(application: sharedApplication) { [weak self] result in
            switch result {
            case .success:
                self?.sendResult(success: true)
            case .error:
                self?.sendResult(success: false)
            }
        }
    }
    
    private func sendResult(success: Bool) {
        // Send result back via NotificationCenter
        let userInfo = ["success": success]
        NotificationCenter.default.post(
            name: NSNotification.Name("PPGSubscriptionResult"),
            object: nil,
            userInfo: userInfo
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
