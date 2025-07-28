//
//  EventManager.swift
//  PPG_framework
//
//  Created by PushPushGo on 17/10/2024.
//  Copyright © 2024 Goodylabs. All rights reserved.
//
//

import Foundation
import UserNotifications

class EventManager {
    private let sharedData: SharedData
    private let eventSender: EventSender
    
    // Thread-safe event operations queue
    private let eventQueue = DispatchQueue(label: "com.pushpushgo.eventmanager", qos: .utility)
    
    private var cachedEvents: [Event]?
    private var isSyncing = false

    init(sharedData: SharedData, eventSender: EventSender = DefaultEventSender()) {
        self.sharedData = sharedData
        self.eventSender = eventSender
    }

    public func notificationDelivered(notificationRequest: UNNotificationRequest,
                                      handler: @escaping (_ result: ActionResult) -> Void) {
        let notificationContent = notificationRequest.content

        guard let campaign = notificationContent.userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign, sender: self.eventSender)
        register(event: deliveryEvent, handler: handler)
    }

    public func registerNotificationDeliveredFromUserInfo(userInfo: [AnyHashable: Any],
                                                          handler: @escaping (_ result: ActionResult) -> Void) {
        guard let campaign = userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign, sender: self.eventSender)
        register(event: deliveryEvent, handler: handler)
    }

    public func notificationClicked(response: UNNotificationResponse) {
        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: 0,
                               campaign: campaign ?? "", sender: self.eventSender)
        register(event: clickEvent) { result in print(result) }
    }

    public func notificationButtonClicked(
        response: UNNotificationResponse, button: Int) {

        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: button,
                               campaign: campaign ?? "", sender: self.eventSender)
        register(event: clickEvent) { result in print(result) }
    }


    public func sync(handler: @escaping (_ result: [Event]) -> Void) {
        eventQueue.async {
            self.syncUnsafe(handler: handler)
        }
    }
    
    private func syncUnsafe(handler: @escaping (_ result: [Event]) -> Void) {
        // Prevent concurrent syncs
        guard !isSyncing else {
            DispatchQueue.main.async {
                handler([])
            }
            return
        }
        
        isSyncing = true
        
        let allEvents = getEventsUnsafe()
        let validEvents = allEvents.filter { !$0.canDelete() }
        let eventsToSend = validEvents.filter { !$0.wasSent() }
        
        guard !eventsToSend.isEmpty else {
            isSyncing = false
            DispatchQueue.main.async {
                handler([])
            }
            return
        }
        let dispatchGroup = DispatchGroup()
        
        eventsToSend.forEach { event in
            dispatchGroup.enter()
            self.sendEventWithRetry(event: event, retryCount: 2) { result in
                switch result {
                case .success:
                    break
                case .error(let message):
                    print("PPG EventManager: Failed to send event: \(message)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: self.eventQueue) {
            // Check if any new events were added during sending
            let currentEvents = self.getEventsUnsafe()
            let eventsToKeep = currentEvents.filter { !$0.canDelete() }
            self.setEventsUnsafe(events: eventsToKeep)
            
            self.isSyncing = false
            DispatchQueue.main.async {
                handler(eventsToSend)
            }
        }
    }


    public func register(event: Event, handler: @escaping (_ result: ActionResult) -> Void) {
        eventQueue.async {
            var events = self.getEventsUnsafe()
            
            if events.contains(where: { $0.softEquals(event) }) {
                DispatchQueue.main.async {
                    handler(.error("Event was sent before. Omitting"))
                }
                return
            }
            
            events.append(event)
            self.setEventsUnsafe(events: events)

            if !self.isSyncing {
                self.syncUnsafe { result in
                    DispatchQueue.main.async {
                        handler(.success)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    handler(.success)
                }
            }
        }
    }

    //Thread-safe cache-aware methods
    
    private func getEventsUnsafe() -> [Event] {
        if let cached = cachedEvents {
            return cached
        }
        
        let events = loadEventsFromStorage()
        cachedEvents = events
        return events
    }
    
    private func setEventsUnsafe(events: [Event]) {
        cachedEvents = events
        saveEventsToStorage(events: events)
    }
    
    private func invalidateCache() {
        cachedEvents = nil
    }
    
    //Storage methods
    
    private func loadEventsFromStorage() -> [Event] {
        guard let data = self.sharedData.sharedDefaults?.data(forKey: "SavedPPGEvents") else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = ISO8601DateFormatter.custom.date(from: dateString) {
                return date
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
        }
        
        do {
            let events = try decoder.decode([Event].self, from: data)
            return events
        } catch {
            print("PPG EventManager: Decoding error: \(error)")
            return []
        }
    }
    
    private func saveEventsToStorage(events: [Event]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = ISO8601DateFormatter.custom.string(from: date)
            try container.encode(dateString)
        }
        
        do {
            let data = try encoder.encode(events)
            self.sharedData.sharedDefaults?.set(data, forKey: "SavedPPGEvents")
        } catch {
            print("PPG EventManager: Encoding error: \(error)")
        }
    }
    
    // Retry mechanism
    
    private func sendEventWithRetry(event: Event, retryCount: Int, handler: @escaping (ActionResult) -> Void) {
        event.send(sender: eventSender) { result in
            switch result {
            case .success:
                handler(.success)
            case .error(let message):
                if retryCount > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.sendEventWithRetry(event: event, retryCount: retryCount - 1, handler: handler)
                    }
                } else {
                    handler(.error("Failed after retries: \(message)"))
                }
            }
        }
    }
    
    //Monitoring
    
    public func getEventStats() -> (total: Int, sent: Int, pending: Int, expired: Int) {
        return eventQueue.sync {
            let events = getEventsUnsafe()
            return (
                total: events.count,
                sent: events.filter { $0.wasSent() }.count,
                pending: events.filter { !$0.wasSent() }.count,
                expired: events.filter { $0.isExpired() }.count
            )
        }
    }
    
    public func debugPrintEvents() {
        eventQueue.async {
            let events = self.getEventsUnsafe()
            print("PPG EventManager: Current events (\(events.count)):")
            events.forEach { event in
                print("  - \(event.description)")
            }
        }
    }


    //Legacy public methods (thread-safe wrappers)
    
    public func getEvents() -> [Event] {
        return eventQueue.sync {
            return getEventsUnsafe()
        }
    }

    public func setEvents(events: [Event]) {
        eventQueue.async {
            self.setEventsUnsafe(events: events)
        }
    }

    public func clearEvents() {
        eventQueue.async {
            self.sharedData.sharedDefaults?.removeObject(forKey: "SavedPPGEvents")
            self.invalidateCache()
        }
    }
}

extension ISO8601DateFormatter {
    static let custom: ISO8601DateFormatter = Event.iso8601DateFormatter
}
