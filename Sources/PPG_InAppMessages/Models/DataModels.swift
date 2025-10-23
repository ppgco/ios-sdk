import Foundation

// InAppMessage
internal struct InAppMessage: Codable {
    let id: String
    let name: String
    let html: String
    let css: String
    let enabled: Bool
    
    // Layout and styling
    let layout: MessageLayout
    let style: MessageStyle
    let title: MessageTitle?
    let description: MessageDescription?
    let image: MessageImage?
    
    // Actions and interactions
    let actions: [InAppMessageAction]
    
    // Targeting and scheduling
    let audience: MessageAudience
    let settings: MessageScheduleSettings
    
    // Timestamps
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    
    let template: String?
}

// Supporting Structures
internal struct MessageLayout: Codable {
    let placement: String // "TOP", "CENTER", "BOTTOM"
    let margin: String
    let padding: String
    let paddingBody: String
    let spaceBetweenImageAndBody: Int
    let spaceBetweenContentAndActions: Int
    let spaceBetweenTitleAndDescription: Int
}

internal struct MessageStyle: Codable {
    let backgroundColor: String
    let borderRadius: String
    let border: Bool
    let borderColor: String
    let borderWidth: Int
    let fontFamily: String
    let fontUrl: String?
    let closeIcon: Bool
    let closeIconColor: String
    let closeIconWidth: Int
    let zIndex: Int
    let animationType: String
    let dropShadow: Bool
    let overlay: Bool
}

internal struct MessageTitle: Codable {
    let text: String
    let fontSize: Int
    let color: String
    let fontWeight: Int
    let alignment: String
    let style: String
}

internal struct MessageDescription: Codable {
    let text: String
    let fontSize: Int
    let color: String
    let fontWeight: Int
    let alignment: String
    let style: String
}

internal struct MessageImage: Codable {
    let url: String
    let hideOnMobile: Bool
}

internal struct MessageAudience: Codable {
    let userType: String // "ALL", "SUBSCRIBER", "NON_SUBSCRIBER", "NOTIFICATIONS_BLOCKED"
    let device: [String]
    let userAgent: [String]
    let osType: [String]
    let platform: String // "ALL", "WEB", "MOBILE"
}

// Route Display Settings
internal struct RouteDisplayConfig: Codable {
    let display: Bool
    let path: String
}

internal struct MessageScheduleSettings: Codable {
    let triggerType: String // "ENTER", "CUSTOM", "SCROLL", "EXIT_INTENT"
    let scrollDepth: Int
    let showAfterDelay: Int
    let display: String
    let displayOn: [RouteDisplayConfig]
    let showAgain: String
    let showAfterTime: Int
    let priority: Int
    let customTriggerKey: String?
    let customTriggerValue: String?
}

// InAppMessageAction
internal struct InAppMessageAction: Codable {
    let enabled: Bool
    let actionType: String // "REDIRECT", "SUBSCRIBE", "CLOSE", "JS"
    let url: String?
    let target: String
    let text: String
    let fontSize: Int
    let fontWeight: Int
    let style: String
    let textColor: String
    let backgroundColor: String
    let borderColor: String
    let borderRadius: String
    let padding: String
    let call: String?
}

// Enums
internal enum UserAudienceType: String, CaseIterable, Codable {
    case all = "ALL"
    case subscriber = "SUBSCRIBER"
    case nonSubscriber = "NON_SUBSCRIBER"
    case notificationsBlocked = "NOTIFICATIONS_BLOCKED"
}

internal enum TriggerType: String, CaseIterable, Codable {
    case enter = "ENTER"
    case custom = "CUSTOM_TRIGGER"
    case scroll = "SCROLL"
    case exitIntent = "EXIT_INTENT"
}

internal enum ActionType: String, CaseIterable, Codable {
    case redirect = "REDIRECT"
    case subscribe = "SUBSCRIBE"
    case close = "CLOSE"
    case js = "JS"
}

internal enum PlatformType: String, CaseIterable, Codable {
    case all = "ALL"
    case web = "WEB"
    case mobile = "MOBILE"
}

internal enum DeviceType: String, CaseIterable, Codable {
    case all = "ALL"
    case mobile = "MOBILE"
    case desktop = "DESKTOP"
    case tablet = "TABLET"
    case others = "OTHERS"
}

internal enum OSType: String, CaseIterable, Codable {
    case all = "ALL"
    case ios = "IOS"
    case android = "ANDROID"
    case windows = "WINDOWS"
    case mac = "MACOS"
    case others = "OTHERS"
}

// Event Models
internal struct InAppEvent: Codable {
    let eventType: String
    let messageId: String
    let timestamp: Date
    
    init(eventType: String, messageId: String) {
        self.eventType = eventType
        self.messageId = messageId
        self.timestamp = Date()
    }
}

// API Response Models
internal struct MessagesResponse: Codable {
    let data: [InAppMessage]
    let metadata: ResponseMetadata
}

internal struct ResponseMetadata: Codable {
    let total: Int
}

internal struct EventResponse: Codable {
    let success: Bool
    let error: String?
}

// Extensions for convenience
extension InAppMessage {
    /// Check if message matches the given audience type
    func matchesAudience(provider: PushNotificationStatusProvider) -> Bool {
        guard let audienceType = UserAudienceType(rawValue: audience.userType) else {
            return false
        }
        return provider.matchesAudienceType(audienceType)
    }
    
    /// Check if message matches the given trigger type
    func matchesTrigger(_ trigger: TriggerType) -> Bool {
        return TriggerType(rawValue: settings.triggerType) == trigger
    }
    
    /// Check if message matches the current platform (iOS = MOBILE)
    func matchesPlatform() -> Bool {
        guard let platformType = PlatformType(rawValue: audience.platform) else {
            return false
        }
        return platformType == .mobile || platformType == .all
    }
    
    /// Check if message matches the device type targeting
    /// For iOS SDK: show only if device contains ALL or MOBILE
    func matchesDevice() -> Bool {
        // Check if any device type in the array allows iOS (MOBILE or ALL)
        return audience.device.contains { deviceString in
            guard let deviceType = DeviceType(rawValue: deviceString) else {
                return false
            }
            return deviceType == .mobile || deviceType == .all
        }
    }
    
    /// Check if message matches the OS type targeting
    /// For iOS SDK: show only if osType contains ALL or IOS
    func matchesOSType() -> Bool {
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
    func actions(ofType actionType: ActionType) -> [InAppMessageAction] {
        return actions.filter { ActionType(rawValue: $0.actionType) == actionType }
    }
}
