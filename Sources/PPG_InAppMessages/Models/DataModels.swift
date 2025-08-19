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
}

public struct MessageScheduleSettings: Codable {
    public let triggerType: String // "ENTER", "CUSTOM", "SCROLL", "EXIT_INTENT"
    public let scrollDepth: Int
    public let showAfterDelay: Int
    public let display: String
    public let displayOn: [String]
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
    public let actionType: String // "REDIRECT", "SUBSCRIBE", "CLOSE", "CUSTOM"
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
    case custom = "CUSTOM"
    case scroll = "SCROLL"
    case exitIntent = "EXIT_INTENT"
}

// Reference: Android ActionType.kt
public enum ActionType: String, CaseIterable, Codable {
    case redirect = "REDIRECT"
    case subscribe = "SUBSCRIBE"
    case close = "CLOSE"
    case custom = "CUSTOM"
}

// MARK: - Event Models
public struct InAppEvent: Codable {
    public let eventType: String
    public let messageId: String
    public let userId: String?
    public let timestamp: Date
    
    public init(eventType: String, messageId: String, userId: String? = nil) {
        self.eventType = eventType
        self.messageId = messageId
        self.userId = userId
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
    
    /// Get actions of specific type
    public func actions(ofType actionType: ActionType) -> [InAppMessageAction] {
        return actions.filter { ActionType(rawValue: $0.actionType) == actionType }
    }
}

extension UserAudienceType {
    /// Human-readable description
    public var description: String {
        switch self {
        case .all:
            return "All Users"
        case .subscriber:
            return "Subscribers"
        case .nonSubscriber:
            return "Non-Subscribers"
        case .notificationsBlocked:
            return "Notifications Blocked"
        }
    }
}

extension TriggerType {
    /// Human-readable description
    public var description: String {
        switch self {
        case .enter:
            return "Page Entry"
        case .custom:
            return "Custom Event"
        case .scroll:
            return "Scroll Depth"
        case .exitIntent:
            return "Exit Intent"
        }
    }
}

extension ActionType {
    /// Human-readable description
    public var description: String {
        switch self {
        case .redirect:
            return "Redirect"
        case .subscribe:
            return "Subscribe"
        case .close:
            return "Close"
        case .custom:
            return "Custom"
        }
    }
}
