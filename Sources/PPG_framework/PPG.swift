//
//  PPG.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 13/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

// Global bridge instance - initialized when PPG is first used
private let subscriptionBridge = PushPushGoSubscriptionBridgeManager()

public class PPG: NSObject, UNUserNotificationCenterDelegate {

    // Shared instance of PPG for handling notification delegate methods
    public static let shared = PPG()
    
    public static var subscriberId: String {
        return SharedData.shared.subscriberId
    }

    override public init() {
        super.init()
    }

    public static func initializeNotifications(
        projectId: String, apiToken: String, appGroupId: String
    ) {
        // Validate required parameters
        guard !projectId.isEmpty else {
            fatalError("PPG SDK: projectId cannot be empty")
        }
        guard !apiToken.isEmpty else {
            fatalError("PPG SDK: apiToken cannot be empty")
        }
        
        // Initialize bridge for In-App Messages communication
        _ = subscriptionBridge // Force initialization
        SharedData.shared.appGroupId = appGroupId
        SharedData.shared.projectId = projectId
        SharedData.shared.apiToken = apiToken
        SharedData.shared.center = UNUserNotificationCenter.current()
        
        // Register default notification categories
        CategoryManager.addDefaultCategories()
        
        // Check current notification permissions on startup
        // This will also clear subscriber data if permissions are denied
        SharedData.shared.checkAndUpdateNotificationPermissions()
        
        // Check if user is already subscribed (has device token saved)
        let hasDeviceToken = !SharedData.shared.deviceToken.isEmpty
        SharedData.shared.isSubscribed = hasDeviceToken
    }

    public static func registerForNotifications(
        application: UIApplication,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        SharedData.shared.center.requestAuthorization(options: [
            .alert, .sound, .badge,
        ]) { granted, error in
            if let error = error {
                print("Init Notifications error: \(error)")
                // Update subscription status - permission denied
                SharedData.shared.updateSubscriptionStatus(isSubscribed: false)
                handler(.error(error.localizedDescription))
                return
            }

            // Check if user granted permission
            guard granted else {
                print("Init Notifications denied by user")
                // Clear subscriber data immediately when user denies
                SharedData.shared.clearSubscriberData()
                SharedData.shared.areNotificationsBlocked = true
                handler(.error("User denied notification permissions"))
                return
            }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
            print("Init Notifications success")
            
            // Update subscription status based on permission granted
            // Note: This doesn't guarantee subscription yet - wait for device token
            SharedData.shared.checkAndUpdateNotificationPermissions()

            handler(.success)
        }
    }

    public static func changeProjectIdAndToken(
        _ projectId: String, _ apiToken: String
    ) {
        SharedData.shared.projectId = projectId
        SharedData.shared.apiToken = apiToken
    }

    public static func sendDeviceToken(
        _ token: Data, handler: @escaping (_ result: ActionResult) -> Void
    ) {
        let tokenParts = token.map { data in String(format: "%02.2hhx", data) }
        let key = tokenParts.joined()
        let oldKey = SharedData.shared.deviceToken

        print("Device token \(key.prefix(8))…")

        if oldKey == key {
            // Token already registered
            handler(.success)
            return
        }

        ApiService.shared.subscribeUser(token: key) { result in
            if case .success = result {
                SharedData.shared.deviceToken = key
                // Successfully subscribed - update status
                SharedData.shared.updateSubscriptionStatus(isSubscribed: true)
            } else {
                // Failed to subscribe - update status
                SharedData.shared.updateSubscriptionStatus(isSubscribed: false)
            }

            handler(result)
        }
    }

    public static func resendDeviceToken(
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        let token = SharedData.shared.deviceToken
        if token == "" {
            handler(.error("Token is not available"))
            return
        }

        ApiService.shared.subscribeUser(token: token) { result in
            if case .success = result {
                // Successfully re-subscribed - update status
                SharedData.shared.updateSubscriptionStatus(isSubscribed: true)
            } else {
                // Failed to re-subscribe - update status
                SharedData.shared.updateSubscriptionStatus(isSubscribed: false)
            }
            handler(result)
        }
    }

    public static func unsubscribeUser(
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        ApiService.shared.unsubscribeUser { result in
            if case .success = result {
                // Clear all subscriber data
                SharedData.shared.clearSubscriberData()
            }

            handler(result)
        }
    }

    /// Mark given notification as delivered to the user
    /// This should be called in your NotificationServiceExtension
    ///
    /// - Parameter notificationRequest: UNNotificationRequest
    public static func notificationDelivered(
        notificationRequest: UNNotificationRequest,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        EventManager.shared.notificationDelivered(notificationRequest: notificationRequest, handler: handler)
    }

    @available(
        *,
        deprecated,
        message: "Delivery events are now registered from the Notification Service Extension. This method no longer needs to be called."
    )
    public static func registerNotificationDeliveredFromUserInfo(
        userInfo: [AnyHashable: Any],
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        EventManager.shared.notificationDelivered(userInfo: userInfo, handler: handler)
    }

    @available(*, deprecated, message: "Use notificationClicked(response:handler:) instead.")
    public static func notificationClicked(response: UNNotificationResponse) {
        notificationClicked(response: response) { _ in }
    }

    public static func notificationClicked(
        response: UNNotificationResponse,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        EventManager.shared.notificationClicked(response: response, handler: handler)
    }

    @available(*, deprecated, message: "Use notificationButtonClicked(response:button:handler:) instead.")
    public static func notificationButtonClicked(response: UNNotificationResponse, button: Int) {
        notificationButtonClicked(response: response, button: button) { _ in }
    }

    public static func notificationButtonClicked(
        response: UNNotificationResponse,
        button: Int,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        EventManager.shared.notificationClicked(
            response: response,
            button: button,
            handler: handler
        )
    }

    // Get supported URL schemes from Info.plist or fall back to defaults
    public static func getSupportedUrlSchemes() -> [String] {
        if let urlSchemes = Bundle.main.object(forInfoDictionaryKey: "PPGSupportedURLSchemes") as? [String], !urlSchemes.isEmpty {
            return urlSchemes
        }
        return ["http", "https", "app"]
    }

    private static func isUrlWithSupportedScheme(_ urlString: String) -> Bool {
        let schemes = getSupportedUrlSchemes()
        return schemes.contains { scheme in urlString.starts(with: scheme) }
    }
    
    public static func getUrlFromNotificationResponse(
        response: UNNotificationResponse
    ) -> (URL?, Bool) {
        let userInfo = response.notification.request.content.userInfo
        
        // Check for URL in actions array
        // For specific button clicks
        if response.actionIdentifier != UNNotificationDefaultActionIdentifier,
           let actions = userInfo["actions"] as? [[String: Any]] {
            let index: Int
            switch response.actionIdentifier {
            case "button_1":
                index = 0
            case "button_2":
                index = 1
            default:
                return (nil, false)
            }
            
            guard index < actions.count,
                let urlString = actions[index]["url"] as? String,
                isUrlWithSupportedScheme(urlString),
                let url = URL(string: urlString) else {
                return (nil, false)
            }
            
            // Check if this action button URL should be treated as a Universal Link
            let isUniversalLink = actions[index]["UL"] as? Bool ?? false
            return (url, isUniversalLink)
        }
        
        // Fallback to default url
        if let aps = userInfo["aps"] as? [String: Any],
           let urlArgs = aps["url-args"] as? [String],
           let link = urlArgs.first,
           isUrlWithSupportedScheme(link),
           let url = URL(string: link) {
            // Check root level UL flag for default click URL
            let isUniversalLink = userInfo["UL"] as? Bool ?? false
            return (url, isUniversalLink)
        }
        
        return (nil, false)
    }
    
    @available(*, deprecated, message: "Use modifyNotification(_:completion:) instead.")
    public static func modifyNotification(
        _ notification: UNMutableNotificationContent
    ) -> UNMutableNotificationContent {
        // Handle image attachment if present
        if let imageUrl = notification.userInfo["image"] as? String,
           let attachement = try? UNNotificationAttachment(url: imageUrl) {
            notification.attachments = [attachement]
        }

        let group = DispatchGroup()

        group.enter()
        prepareNotificationCategories(for: notification) { categoryId in
            notification.categoryIdentifier = categoryId
            group.leave()
        }

        group.wait()

        return notification
    }

    public static func modifyNotification(
        _ notification: UNMutableNotificationContent,
        completion: @escaping () -> Void
    ) {
        let group = DispatchGroup()

        group.enter()
        prepareNotificationCategories(for: notification) { categoryId in
            DispatchQueue.main.async {
                notification.categoryIdentifier = categoryId
                group.leave()
            }
        }

        group.enter()
        downloadNotificationImage(from: notification.userInfo["image"] as? String) { attachment in
            DispatchQueue.main.async {
                if let attachment = attachment {
                    notification.attachments = [attachment]
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    private static func prepareNotificationCategories(
        for notification: UNMutableNotificationContent,
        completion: @escaping (String) -> Void
    ) {
        let actions = notification.userInfo["actions"] as? [[String: Any]]
        let categoryId = notification.categoryIdentifier

        UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
            var updatedCategories = existingCategories
            var categoryId = categoryId

            // Process actions from payload
            if let actions = actions, !actions.isEmpty {
                let dynamicActions = NotificationActionBuilder.createUniqueActions(from: actions)
                
                // Use existing category ID or generate a new one
                categoryId = categoryId.isEmpty ?
                               "\(CategoryManager.dynamicCategoryPrefix)\(UUID().uuidString)" : categoryId
                
                // Create category
                let category = UNNotificationCategory(
                    identifier: categoryId,
                    actions: dynamicActions,
                    intentIdentifiers: [],
                    options: []
                )

                // Keep all existing categories except the one we're updating
                updatedCategories = updatedCategories.filter { $0.identifier != categoryId }
                updatedCategories.insert(category)

                CategoryManager.saveCategory(id: categoryId, actions: dynamicActions)
                print("PPG SDK - Added category: \(categoryId)")
            } else {
                categoryId = CategoryManager.defaultCategoryId
                print("PPG SDK - Using default category")
            }
            
            // Get valid stored categories
            let storedCategoryIds = Set(CategoryManager.loadStoredCategories().map { $0.id })

            updatedCategories = updatedCategories.filter { category in
                guard category.identifier.hasPrefix(CategoryManager.dynamicCategoryPrefix) else {
                    return true
                }

                return storedCategoryIds.contains(category.identifier)
            }

            // Update notification center
            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
            print("PPG SDK - Categories after update: \(updatedCategories.map { $0.identifier })")

            completion(categoryId)
        }
    }

    private static func downloadNotificationImage(
        from imageUrlString: String?,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        guard let imageUrlString = imageUrlString,
              let imageUrl = URL(string: imageUrlString) else {
            completion(nil)
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        
        let session = URLSession(configuration: configuration)

        session.downloadTask(with: imageUrl) { temporaryUrl, response, error in
            defer { session.finishTasksAndInvalidate() }

            guard error == nil,
                  let temporaryUrl = temporaryUrl else {
                completion(nil)
                return
            }

            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                completion(nil)
                return
            }

            guard let pathExtension = response.url?.pathExtension,
                  !pathExtension.isEmpty else {
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let attachmentUrl = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(pathExtension)

            do {
                try fileManager.moveItem(at: temporaryUrl, to: attachmentUrl)
                let attachment = try UNNotificationAttachment(
                    identifier: attachmentUrl.lastPathComponent,
                    url: attachmentUrl,
                    options: nil
                )
                completion(attachment)
            } catch {
                try? fileManager.removeItem(at: attachmentUrl)
                completion(nil)
            }
        }.resume()
    }

    public static func sendEventsDataToApi() {
        EventManager.shared.sync()
    }

    public static func sendBeacon(
        _ beacon: Beacon, handler: @escaping (_ result: ActionResult) -> Void
    ) {
        ApiService.shared.sendBeacon(beacon: beacon, handler: handler)
    }
    
    @available(
        *,
        deprecated,
        message: "Event history is no longer retained. This method returns pending events only."
    )
    public static func getEvents() -> [EventDTO] {
        return EventManager.shared.getEvents().map {$0.toDTO()}
    }
    
    //UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Display notification when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let registerClick: (@escaping (ActionResult) -> Void) -> Void = { handler in
            if actionIdentifier == UNNotificationDefaultActionIdentifier {
                // User tapped the notification itself
                PPG.notificationClicked(response: response, handler: handler)
            } else if actionIdentifier == "button_1" {
                PPG.notificationButtonClicked(response: response, button: 1, handler: handler)
            } else if actionIdentifier == "button_2" {
                PPG.notificationButtonClicked(response: response, button: 2, handler: handler)
            } else {
                // Track as regular notification click for unknown actions
                PPG.notificationClicked(response: response, handler: handler)
            }
        }

        registerClick { _ in
            // Handle URL opening if present
            let (responseUrl, isUniversalLink) = PPG.getUrlFromNotificationResponse(response: response)

            if let url = responseUrl {
                // Get UIApplication.shared safely using reflection
                guard let sharedApplication = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else {
                    completionHandler()
                    return
                }
                
                if isUniversalLink {
                    // Handle as Universal Link using NSUserActivity
                    let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                    userActivity.webpageURL = url

                    DispatchQueue.main.async {
                        // Pass to app delegate
                        if let appDelegate = sharedApplication.delegate,
                           appDelegate.responds(to: #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))) {
                            _ = appDelegate.application?(sharedApplication, continue: userActivity, restorationHandler: { _ in })
                        } else {
                            // Fallback if app delegate can't handle it
                            sharedApplication.open(url)
                        }
                    }
                } else {
                    // Open as regular URL in browser
                    DispatchQueue.main.async {
                        sharedApplication.open(url)
                    }
                }
            }
            completionHandler()
        }
    }

}
