//
//  Event.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright 2020 Goodylabs. All rights reserved.
//

import Foundation

public struct EventDTO {
    init(event: Event) {
        self.timestamp = event.timestamp
        self.type = event.eventType.rawValue
        self.campaign = event.campaign
        self.button = event.button
        self.sentAt = event.sentAt
    }
    
    public var timestamp: String
    public var type: String
    public var campaign: String
    public var button: Int?
    public var sentAt: Date?
}

// Protocol defining the method for sending events.
protocol EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
}

class Event: Codable, CustomStringConvertible {

    public var eventType: EventType
    public var timestamp: String  // ISO8601 formatted timestamp
    public var button: Int?
    public var campaign: String
    public var sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case eventType
        case timestamp
        case button
        case campaign
        case sentAt
    }

    // Custom ISO8601DateFormatter with options to handle fractional seconds and Zulu timezone.
    static let iso8601DateFormatter: ISO8601DateFormatter =
        {
            var options: ISO8601DateFormatter.Options = [
                .withInternetDateTime,
                .withColonSeparatorInTimeZone,
            ]
            if #available(iOS 11.0, *) {
                options.insert(.withFractionalSeconds)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            return formatter
        }()

    init(
        eventType: EventType = .delivered, button: Int? = nil,
        campaign: String = "", sender: EventSender? = DefaultEventSender()
    ) {
        self.eventType = eventType
        self.timestamp = Event.iso8601DateFormatter.string(from: Date())
        self.button = button
        self.campaign = campaign
        self.sentAt = nil
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        button = try container.decodeIfPresent(Int.self, forKey: .button)
        campaign = try container.decode(String.self, forKey: .campaign)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(button, forKey: .button)
        try container.encode(campaign, forKey: .campaign)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
    }

    public var description: String {
        let buttonStr = button.map { "\($0)" } ?? "none"
        let sentAtStr = sentAt.map { Event.iso8601DateFormatter.string(from: $0) } ?? "not sent"
        return """
        Event(type: \(eventType.rawValue), timestamp: \(timestamp), button: \(buttonStr), campaign: '\(campaign)', sentAt: \(sentAtStr))
        """
    }
    
    public func toDTO() -> EventDTO {
        return EventDTO(event: self)
    }
    
    func getKey() -> String {
        return "\(eventType.rawValue)_\(button ?? 0)_\(campaign)"
    }

    func send(
        sender: EventSender, handler: @escaping (_ result: ActionResult) -> Void
    ) {
        if self.wasSent() {
            DispatchQueue.main.async {
                handler(.error("Event was sent before"))
            }
            return
        }
        sender.send(event: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.sentAt = Date()
                    handler(result)
                case .error:
                    handler(result)
                }
            }
        }
    }

    func wasSent() -> Bool {
        return sentAt != nil
    }

    func canDelete() -> Bool {
        return wasSent() && isExpired()
    }

    func isExpired() -> Bool {
        guard let sentAt = self.sentAt else { return false }
        return Date().timeIntervalSince(sentAt) > 7 * 24 * 60 * 60  // 7 days
    }

    func debug() {
        print(getKey(), sentAt as Any, wasSent(), isExpired())
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.button == rhs.button && lhs.campaign == rhs.campaign
            && lhs.eventType == rhs.eventType && lhs.timestamp == rhs.timestamp
    }

    func softEquals(_ other: Event) -> Bool {
        return button == other.button && campaign == other.campaign
            && eventType == other.eventType
    }
}

// Default implementation of EventSender using the production API service.
class DefaultEventSender: EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
    {
        ApiService.shared.sendEvent(event: event, handler: handler)
    }
}

class MockEventSender: EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
    {
        // Simulate asynchronous success after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            handler(.success)
        }
    }
}
