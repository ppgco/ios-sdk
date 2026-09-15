import Foundation
import UserNotifications

class EventManager {
    static let shared = EventManager()

    private enum SyncState {
        case idle
        case running
        case rerunRequested
    }
    
    private let eventSender: EventSender
    private let eventPersistence: EventPersistence

    private let eventQueue = DispatchQueue(
        label: "com.pushpushgo.push.eventmanager.event",
        qos: .utility
    )
    private let uploadQueue = DispatchQueue(
        label: "com.pushpushgo.push.eventmanager.upload",
        qos: .utility
    )

    private var syncState: SyncState = .idle
    private var isRetryScheduled = false
    private let nseTimeout: TimeInterval = 60
    private let initialRetryTimeout: TimeInterval = 30
    private let maximumRetryTimeout: TimeInterval = 15 * 60
    private let eventExpirationTimeout: TimeInterval = 7 * 24 * 60 * 60

    init(
        eventPersistence: EventPersistence = UserDefaultsEventPersistence(),
        eventSender: EventSender = DefaultEventSender()
    ) {
        self.eventPersistence = eventPersistence
        self.eventSender = eventSender
    }

    func notificationDelivered(
        notificationRequest: UNNotificationRequest,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        guard let campaign = notificationRequest.content.userInfo["campaign"] as? String,
            !campaign.isEmpty
        else {
            handler(.error("Campaign ID is required"))
            return
        }

        let event = anEvent(
            eventType: .delivered,
            campaign: campaign
        )

        persist(event) { result in
            guard case .success = result else {
                DispatchQueue.main.async {
                    handler(result)
                }
                return
            }

            self.eventSender.send(event: event) { result in
                self.eventQueue.async {
                    switch result {
                    case .success, .permanentFailure(_):
                        self.eventPersistence.remove(id: event.id)
                    case .retryableFailure(let message), .platformFailure(let message):
                        print("PPG EventManager: Failed to send event: \(message)")
                        self.recordFailure(for: event)
                    }

                    DispatchQueue.main.async {
                        handler(.success)
                    }
                }
            }
        }
    }

    func notificationDelivered(
        userInfo: [AnyHashable: Any],
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        guard let campaign = userInfo["campaign"] as? String,
            !campaign.isEmpty
        else {
            handler(.error("Campaign ID is required"))
            return
        }

        registerForSync(
            anEvent(eventType: .delivered, campaign: campaign),
            handler: handler
        )
    }

    func notificationClicked(
        response: UNNotificationResponse,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        guard let campaign = response.notification.request.content.userInfo["campaign"] as? String,
            !campaign.isEmpty
        else {
            handler(.error("Campaign ID is required"))
            return
        }

        registerForSync(
            anEvent(eventType: .clicked, button: 0, campaign: campaign),
            handler: handler
        )
    }

    func notificationClicked(
        response: UNNotificationResponse,
        button: Int,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        guard let campaign = response.notification.request.content.userInfo["campaign"] as? String,
            !campaign.isEmpty
        else {
            handler(.error("Campaign ID is required"))
            return
        }

        registerForSync(
            anEvent(eventType: .clicked, button: button, campaign: campaign),
            handler: handler
        )
    }

    func sync() {
        eventQueue.async {
            switch self.syncState {
            case .idle:
                self.syncState = .running
                self.startSync()
            case .running:
                self.syncState = .rerunRequested
            case .rerunRequested:
                break
            }
        }
    }

    private func startSync() {
        let events = eventPersistence.load()

        uploadQueue.async {
            for event in events {
                let now = Date()

                if let timestamp = Event.iso8601DateFormatter.date(from: event.timestamp) {
                    let eventAge = now.timeIntervalSince(timestamp)

                    if eventAge >= self.eventExpirationTimeout {
                        self.eventQueue.async {
                            self.eventPersistence.remove(id: event.id)
                        }
                        continue
                    }

                    if event.eventType == .delivered && eventAge < self.nseTimeout {
                        continue
                    }
                }

                if let lastFailureAt = event.lastFailureAt {
                    let retryTimeout = self.retryTimeout(
                        forFailureCount: event.failureCount
                    )

                    if now.timeIntervalSince(lastFailureAt) < retryTimeout {
                        continue
                    }
                }

                let semaphore = DispatchSemaphore(value: 0)
                self.eventSender.send(event: event) { result in
                    self.eventQueue.async {
                        switch result {
                        case .success, .permanentFailure(_):
                            self.eventPersistence.remove(id: event.id)
                        case .retryableFailure(let message), .platformFailure(let message):
                            print("PPG EventManager: Failed to send event: \(message)")
                            self.recordFailure(for: event)
                        }
                        semaphore.signal()
                    }
                }
                semaphore.wait()
            }

            self.eventQueue.async {
                switch self.syncState {
                case .rerunRequested:
                    self.syncState = .running
                    self.startSync()
                case .running:
                    self.syncState = .idle

                    if !self.eventPersistence.load().isEmpty && !self.isRetryScheduled {
                        self.isRetryScheduled = true
                        self.eventQueue.asyncAfter(
                            deadline: .now() + self.initialRetryTimeout
                        ) { [weak self] in
                            guard let self = self else { return }
                            self.isRetryScheduled = false

                            guard case .idle = self.syncState else { return }

                            self.syncState = .running
                            self.startSync()
                        }
                    }
                case .idle:
                    break
                }
            }
        }
    }

    private func retryTimeout(forFailureCount failureCount: Int) -> TimeInterval {
        let exponent = min(max(failureCount - 1, 0), 7)

        return min(
            initialRetryTimeout * pow(2, Double(exponent)),
            maximumRetryTimeout
        )
    }

    private func recordFailure(for event: Event) {
        event.failureCount += 1
        event.lastFailureAt = Date()

        do {
            try eventPersistence.insert(event)
        } catch {
            print("PPG EventManager: Failed to persist retry state: \(error.localizedDescription)")
        }
    }

    private func registerForSync(
        _ event: Event,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        persist(event) { result in
            DispatchQueue.main.async {
                handler(result)
            }

            if case .success = result {
                self.sync()
            }
        }
    }

    private func anEvent(
        eventType: EventType,
        button: Int? = nil,
        campaign: String
    ) -> Event {
        return Event(
            eventType: eventType,
            button: button,
            campaign: campaign,
            projectId: SharedData.shared.projectId,
            apiToken: SharedData.shared.apiToken,
            subscriberId: SharedData.shared.subscriberId
        )
    }

    private func persist(
        _ event: Event,
        completion: @escaping (_ result: ActionResult) -> Void
    ) {
        eventQueue.async {
            guard !event.projectId.isEmpty else {
                completion(.error("Empty Project ID"))
                return
            }

            guard !event.apiToken.isEmpty else {
                completion(.error("Empty API Token"))
                return
            }

            guard !event.subscriberId.isEmpty else {
                completion(.error("Empty Subscriber ID"))
                return
            }

            do {
                try self.eventPersistence.insert(event)
                completion(.success)
            } catch {
                completion(.error("Failed to persist event: \(error.localizedDescription)"))
            }
        }
    }

    func getEvents() -> [Event] {
        return eventPersistence.snapshot()
    }
}
