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

class Event: Codable, CustomStringConvertible {

    let id: UUID
    let eventType: EventType
    let timestamp: String  // ISO8601 formatted timestamp
    let button: Int?
    let campaign: String
    let projectId: String
    let apiToken: String
    let subscriberId: String
    let sentAt: Date?
    var failureCount: Int
    var lastFailureAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventType
        case timestamp
        case button
        case campaign
        case projectId
        case apiToken
        case subscriberId
        case sentAt
        case failureCount
        case lastFailureAt
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
        id: UUID = UUID(),
        eventType: EventType = .delivered,
        button: Int? = nil,
        campaign: String,
        projectId: String,
        apiToken: String,
        subscriberId: String,
        timestamp: String = Event.iso8601DateFormatter.string(from: Date()),
        sentAt: Date? = nil,
        failureCount: Int = 0,
        lastFailureAt: Date? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.timestamp = timestamp
        self.button = button
        self.campaign = campaign
        self.projectId = projectId
        self.apiToken = apiToken
        self.subscriberId = subscriberId
        self.sentAt = sentAt
        self.failureCount = failureCount
        self.lastFailureAt = lastFailureAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        eventType = try container.decode(EventType.self, forKey: .eventType)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        button = try container.decodeIfPresent(Int.self, forKey: .button)
        campaign = try container.decode(String.self, forKey: .campaign)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId) ?? ""
        apiToken = try container.decodeIfPresent(String.self, forKey: .apiToken) ?? ""
        subscriberId = try container.decodeIfPresent(String.self, forKey: .subscriberId) ?? ""
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
        failureCount = try container.decodeIfPresent(Int.self, forKey: .failureCount) ?? 0
        lastFailureAt = try container.decodeIfPresent(Date.self, forKey: .lastFailureAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(button, forKey: .button)
        try container.encode(campaign, forKey: .campaign)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(apiToken, forKey: .apiToken)
        try container.encode(subscriberId, forKey: .subscriberId)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
        try container.encode(failureCount, forKey: .failureCount)
        try container.encodeIfPresent(lastFailureAt, forKey: .lastFailureAt)
    }

    var description: String {
        let buttonStr = button.map { "\($0)" } ?? "none"
        let sentAtStr = sentAt.map { Event.iso8601DateFormatter.string(from: $0) } ?? "not sent"
        return """
        Event(type: \(eventType.rawValue), timestamp: \(timestamp), button: \(buttonStr), campaign: '\(campaign)', sentAt: \(sentAtStr))
        """
    }

    func toDTO() -> EventDTO {
        return EventDTO(event: self)
    }
}
