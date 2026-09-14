import Foundation
import UserNotifications
import XCTest
@testable import PPG_framework

final class PPGFrameworkTests: XCTestCase {
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "com.pushpushgo.tests.\(UUID().uuidString)"
        SharedData.shared.appGroupId = defaultsSuiteName
        SharedData.shared.projectId = "project-id"
        SharedData.shared.apiToken = "api-token"
        SharedData.shared.subscriberId = "subscriber-id"
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
        SharedData.shared.appGroupId = ""
        super.tearDown()
    }

    func testDeliveredEventIsRegistered() {
        let persistence = TestEventPersistence()
        let registered = expectation(description: "Delivered event registered")

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: TestEventSender(result: .platformFailure("Offline"))
        )

        manager.notificationDelivered(userInfo: ["campaign": "campaign-id"]) { result in
            if case .error(let message) = result {
                XCTFail("Event registration failed: \(message)")
            }
            registered.fulfill()
        }

        wait(for: [registered], timeout: 1)
        XCTAssertEqual(persistence.event?.eventType, .delivered)
        XCTAssertEqual(persistence.event?.campaign, "campaign-id")
        XCTAssertEqual(persistence.event?.projectId, "project-id")
        XCTAssertEqual(persistence.event?.apiToken, "api-token")
        XCTAssertEqual(persistence.event?.subscriberId, "subscriber-id")
        XCTAssertNil(persistence.event?.button)
    }

    func testNotificationServiceEventIsSentAndRemoved() {
        let persistence = TestEventPersistence()
        let sender = TestEventSender(result: .success)
        let sent = expectation(description: "Delivered event sent")

        let content = UNMutableNotificationContent()
        content.userInfo = ["campaign": "campaign-id"]
        let request = UNNotificationRequest(
            identifier: "notification-id",
            content: content,
            trigger: nil
        )

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: sender
        )

        manager.notificationDelivered(notificationRequest: request) { result in
            if case .error(let message) = result {
                XCTFail("Event sending failed: \(message)")
            }
            sent.fulfill()
        }

        wait(for: [sent], timeout: 1)
        XCTAssertEqual(sender.sentEvents.count, 1)
        XCTAssertEqual(sender.sentEvents.first?.eventType, .delivered)
        XCTAssertEqual(sender.sentEvents.first?.campaign, "campaign-id")
        XCTAssertEqual(persistence.removedId, sender.sentEvents.first?.id)
        XCTAssertNil(persistence.event)
    }

    func testPendingEventIsSentAndRemovedDuringSync() {
        let event = Event(
            eventType: .clicked,
            button: 0,
            campaign: "campaign-id",
            projectId: "project-id",
            apiToken: "api-token",
            subscriberId: "subscriber-id"
        )
        let persistence = TestEventPersistence(event: event)
        let sender = TestEventSender(result: .success)
        let removed = expectation(description: "Pending event removed")
        persistence.onRemove = { removed.fulfill() }

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: sender
        )

        manager.sync()

        wait(for: [removed], timeout: 1)
        XCTAssertEqual(sender.sentEvents.map(\.id), [event.id])
        XCTAssertEqual(persistence.removedId, event.id)
        XCTAssertNil(persistence.event)
    }

    func testPermanentFailureRemovesEventWithoutRecordingRetry() {
        let event = Event(
            eventType: .clicked,
            button: 0,
            campaign: "campaign-id",
            projectId: "project-id",
            apiToken: "api-token",
            subscriberId: "subscriber-id"
        )
        let persistence = TestEventPersistence(event: event)
        let sender = TestEventSender(result: .permanentFailure("HTTP 400"))
        let removed = expectation(description: "Permanently failed event removed")
        persistence.onRemove = { removed.fulfill() }

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: sender
        )

        manager.sync()

        wait(for: [removed], timeout: 1)
        XCTAssertEqual(sender.sentEvents.map(\.id), [event.id])
        XCTAssertEqual(persistence.removedId, event.id)
        XCTAssertNil(persistence.event)
        XCTAssertEqual(event.failureCount, 0)
        XCTAssertNil(event.lastFailureAt)
    }

    func testLegacyMigrationDropsEventsOlderThanSevenDays() throws {
        let recentTimestamp = Event.iso8601DateFormatter.string(
            from: Date().addingTimeInterval(-(24 * 60 * 60))
        )
        let expiredTimestamp = Event.iso8601DateFormatter.string(
            from: Date().addingTimeInterval(-(8 * 24 * 60 * 60))
        )
        let legacyEvents = [
            LegacyEvent(timestamp: recentTimestamp, campaign: "recent-campaign"),
            LegacyEvent(timestamp: expiredTimestamp, campaign: "expired-campaign")
        ]
        let data = try JSONEncoder().encode(legacyEvents)
        SharedData.shared.sharedDefaults.set(data, forKey: "SavedPPGEvents")

        let migratedEvents = UserDefaultsEventPersistence().load()

        XCTAssertEqual(migratedEvents.count, 1)
        XCTAssertEqual(migratedEvents.first?.campaign, "recent-campaign")
        XCTAssertNil(SharedData.shared.sharedDefaults.data(forKey: "SavedPPGEvents"))
    }

    func testEventWithEmptyCampaignIsRejected() {
        let persistence = TestEventPersistence()
        let rejected = expectation(description: "Event rejected")

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: TestEventSender(result: .success)
        )

        manager.notificationDelivered(userInfo: ["campaign": ""]) { result in
            defer { rejected.fulfill() }

            guard case .error(let message) = result else {
                XCTFail("Expected event registration to fail")
                return
            }

            XCTAssertEqual(message, "Campaign ID is required")
        }

        wait(for: [rejected], timeout: 1)
        XCTAssertNil(persistence.event)
    }

    func testEventWithEmptySubscriberIdIsRejected() {
        let persistence = TestEventPersistence()
        let rejected = expectation(description: "Event rejected")
        SharedData.shared.subscriberId = ""

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: TestEventSender(result: .success)
        )

        manager.notificationDelivered(userInfo: ["campaign": "campaign-id"]) { result in
            defer { rejected.fulfill() }

            guard case .error(let message) = result else {
                XCTFail("Expected event registration to fail")
                return
            }

            XCTAssertEqual(message, "Empty Subscriber ID")
        }

        wait(for: [rejected], timeout: 1)
        XCTAssertNil(persistence.event)
    }

    func testEventWithEmptyProjectIdIsRejected() {
        let persistence = TestEventPersistence()
        let rejected = expectation(description: "Event rejected")
        SharedData.shared.projectId = ""

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: TestEventSender(result: .success)
        )

        manager.notificationDelivered(userInfo: ["campaign": "campaign-id"]) { result in
            defer { rejected.fulfill() }

            guard case .error(let message) = result else {
                XCTFail("Expected event registration to fail")
                return
            }

            XCTAssertEqual(message, "Empty Project ID")
        }

        wait(for: [rejected], timeout: 1)
        XCTAssertNil(persistence.event)
    }

    func testRetryableFailurePersistsRetryState() {
        let event = Event(
            eventType: .delivered,
            campaign: "campaign-id",
            projectId: "project-id",
            apiToken: "api-token",
            subscriberId: "subscriber-id",
            timestamp: Event.iso8601DateFormatter.string(
                from: Date().addingTimeInterval(-61)
            )
        )

        let persistence = TestEventPersistence(event: event)
        let persisted = expectation(description: "Retry state persisted")
        persistence.onInsert = { persisted.fulfill() }

        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: TestEventSender(result: .retryableFailure("HTTP 500"))
        )

        manager.sync()

        wait(for: [persisted], timeout: 1)
        XCTAssertEqual(event.failureCount, 1)
        XCTAssertNotNil(event.lastFailureAt)
    }

    func testEventOlderThanSevenDaysIsRemoved() {
        let event = Event(
            eventType: .clicked,
            button: 0,
            campaign: "campaign-id",
            projectId: "project-id",
            apiToken: "api-token",
            subscriberId: "subscriber-id",
            timestamp: Event.iso8601DateFormatter.string(
                from: Date().addingTimeInterval(-(8 * 24 * 60 * 60))
            )
        )

        let persistence = TestEventPersistence(event: event)
        let removed = expectation(description: "Expired event removed")
        persistence.onRemove = { removed.fulfill() }

        let sender = TestEventSender(result: .success)
        let manager = EventManager(
            eventPersistence: persistence,
            eventSender: sender
        )

        manager.sync()

        wait(for: [removed], timeout: 1)
        XCTAssertEqual(persistence.removedId, event.id)
        XCTAssertTrue(sender.sentEvents.isEmpty)
    }
}

private struct LegacyEvent: Encodable {
    let eventType: EventType = .delivered
    let timestamp: String
    let button: Int? = nil
    let campaign: String
    let sentAt: Date? = nil
}

private final class TestEventPersistence: EventPersistence {
    private(set) var event: Event?
    private(set) var removedId: UUID?
    var onInsert: (() -> Void)?
    var onRemove: (() -> Void)?

    init(event: Event? = nil) {
        self.event = event
    }

    func load() -> [Event] {
        event.map { [$0] } ?? []
    }

    func insert(_ event: Event) throws {
        self.event = event
        onInsert?()
    }

    func remove(id: UUID) {
        removedId = id
        if event?.id == id {
            event = nil
        }
        onRemove?()
    }
}

private final class TestEventSender: EventSender {
    let result: EventSendResult
    private(set) var sentEvents: [Event] = []

    init(result: EventSendResult) {
        self.result = result
    }

    func send(event: Event, handler: @escaping (EventSendResult) -> Void) {
        sentEvents.append(event)
        handler(result)
    }
}
