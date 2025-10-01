// DataModels.swift
// iOS equivalent of Android data models
// Reference: Android InAppMessage.kt, UserAudienceType.kt, TriggerType.kt, ActionType.kt

import Foundation

// MARK: - InAppMessage
// Reference: Android InAppMessage.kt
public struct InAppMessage: Codable {
    public let id: String
    public let name: String
    public let html: String
    public let css: String
    public let enabled: Bool
    
    // Layout and styling
    public let layout: MessageLayout
    public let style: MessageStyle
    public let title: MessageTitle?
    public let description: MessageDescription?
    public let image: MessageImage?
    
    // Actions and interactions
    public let actions: [InAppMessageAction]
    
    // Targeting and scheduling
    public let audience: MessageAudience
    public let settings: MessageScheduleSettings
    
    // Timestamps
    public let createdAt: String
    public let updatedAt: String
    public let deletedAt: String?
    
    public let template: String?
}

// MARK: - Supporting Structures
public struct MessageLayout: Codable {
    public let placement: String // "TOP", "CENTER", "BOTTOM"
    public let margin: String
    public let padding: String
    public let paddingBody: String
    public let spaceBetweenImageAndBody: Int
    public let spaceBetweenContentAndActions: Int
    public let spaceBetweenTitleAndDescription: Int
}

public struct MessageStyle: Codable {
    public let backgroundColor: String
    public let borderRadius: String
    public let border: Bool
    public let borderColor: String
    public let borderWidth: Int
    public let fontFamily: String
    public let fontUrl: String?
    public let closeIcon: Bool
    public let closeIconColor: String
    public let closeIconWidth: Int
    public let zIndex: Int
    public let animationType: String
    public let dropShadow: Bool
    public let overlay: Bool
}

public struct MessageTitle: Codable {
    public let text: String
    public let fontSize: Int
    public let color: String
    public let fontWeight: Int
    public let alignment: String
    public let style: String
}

public struct MessageDescription: Codable {
    public let text: String
    public let fontSize: Int
    public let color: String
    public let fontWeight: Int
    public let alignment: String
    public let style: String
}

public struct MessageImage: Codable {
    public let url: String
    public let hideOnMobile: Bool
}

public struct MessageAudience: Codable {
    public let userType: String // "ALL", "SUBSCRIBER", "NON_SUBSCRIBER", "NOTIFICATIONS_BLOCKED"
    public let device: [String]
    public let userAgent: [String]
    public let osType: [String]
    public let platform: String // "ALL", "WEB", "MOBILE"
}

// MARK: - Route Display Settings
// Reference: Backend display routing configuration
public struct RouteDisplayConfig: Codable {
    public let display: Bool
    public let path: String
}

public struct MessageScheduleSettings: Codable {
    public let triggerType: String // "ENTER", "CUSTOM", "SCROLL", "EXIT_INTENT"
    public let scrollDepth: Int
    public let showAfterDelay: Int
    public let display: String
    public let displayOn: [RouteDisplayConfig]
    public let showAgain: String
    public let showAfterTime: Int
    public let priority: Int
    public let customTriggerKey: String?
    public let customTriggerValue: String?
}

// MARK: - InAppMessageAction
// Reference: Android InAppMessageAction.kt
public struct InAppMessageAction: Codable {
    public let enabled: Bool
    public let actionType: String // "REDIRECT", "SUBSCRIBE", "CLOSE", "JS"
    public let url: String?
    public let target: String
    public let text: String
    public let fontSize: Int
    public let fontWeight: Int
    public let style: String
    public let textColor: String
    public let backgroundColor: String
    public let borderColor: String
    public let borderRadius: String
    public let padding: String
    public let call: String?
}

// MARK: - Enums
// Reference: Android UserAudienceType.kt
public enum UserAudienceType: String, CaseIterable, Codable {
    case all = "ALL"
    case subscriber = "SUBSCRIBER"
    case nonSubscriber = "NON_SUBSCRIBER"
    case notificationsBlocked = "NOTIFICATIONS_BLOCKED"
}

// Reference: Android TriggerType.kt
public enum TriggerType: String, CaseIterable, Codable {
    case enter = "ENTER"
    case custom = "CUSTOM_TRIGGER"
    case scroll = "SCROLL"
    case exitIntent = "EXIT_INTENT"
}

// Reference: Android ActionType.kt
public enum ActionType: String, CaseIterable, Codable {
    case redirect = "REDIRECT"
    case subscribe = "SUBSCRIBE"
    case close = "CLOSE"
    case js = "JS"
}

// Reference: Android PlatformType.kt
public enum PlatformType: String, CaseIterable, Codable {
    case all = "ALL"
    case web = "WEB"
    case mobile = "MOBILE"
}

// Device type targeting for audience filtering
public enum DeviceType: String, CaseIterable, Codable {
    case all = "ALL"
    case mobile = "MOBILE"
    case desktop = "DESKTOP"
    case tablet = "TABLET"
    case others = "OTHERS"
}

// OS type targeting for audience filtering
public enum OSType: String, CaseIterable, Codable {
    case all = "ALL"
    case ios = "IOS"
    case android = "ANDROID"
    case windows = "WINDOWS"
    case mac = "MACOS"
    case others = "OTHERS"
}

// MARK: - Event Models
public struct InAppEvent: Codable {
    public let eventType: String
    public let messageId: String
    public let timestamp: Date
    
    public init(eventType: String, messageId: String) {
        self.eventType = eventType
        self.messageId = messageId
        self.timestamp = Date()
    }
}

// MARK: - API Response Models
public struct MessagesResponse: Codable {
    public let data: [InAppMessage]
    public let metadata: ResponseMetadata
}

public struct ResponseMetadata: Codable {
    public let total: Int
}

public struct EventResponse: Codable {
    public let success: Bool
    public let error: String?
}

// MARK: - Extensions for convenience
extension InAppMessage {
    /// Check if message matches the given audience type
    /// Reference: Android PushNotificationStatusProvider.matchesAudienceType()
    public func matchesAudience(provider: PushNotificationStatusProvider) -> Bool {
        guard let audienceType = UserAudienceType(rawValue: audience.userType) else {
            return false
        }
        return provider.matchesAudienceType(audienceType)
    }
    
    /// Check if message matches the given trigger type
    public func matchesTrigger(_ trigger: TriggerType) -> Bool {
        return TriggerType(rawValue: settings.triggerType) == trigger
    }
    
    /// Check if message matches the current platform (iOS = MOBILE)
    /// Reference: Android platform checking logic
    public func matchesPlatform() -> Bool {
        guard let platformType = PlatformType(rawValue: audience.platform) else {
            return false
        }
        // iOS is considered MOBILE platform
        return platformType == .mobile || platformType == .all
    }
    
    /// Check if message matches the device type targeting
    /// For iOS SDK: show only if device contains ALL or MOBILE
    public func matchesDevice() -> Bool {
        // Check if any device type in the array allows iOS (MOBILE or ALL)
        return audience.device.contains { deviceString in
            guard let deviceType = DeviceType(rawValue: deviceString) else {
                return false
            }
            // iOS is considered MOBILE device
            return deviceType == .mobile || deviceType == .all
        }
    }
    
    /// Check if message matches the OS type targeting
    /// For iOS SDK: show only if osType contains ALL or IOS
    public func matchesOSType() -> Bool {
        // Check if any OS type in the array allows iOS
        return audience.osType.contains { osString in
            guard let osType = OSType(rawValue: osString) else {
                return false
            }
            // Show for ALL or IOS specifically
            return osType == .ios || osType == .all
        }
    }
    
    /// Get actions of specific type
    public func actions(ofType actionType: ActionType) -> [InAppMessageAction] {
        return actions.filter { ActionType(rawValue: $0.actionType) == actionType }
    }
}
