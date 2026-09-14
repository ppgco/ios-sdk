import Foundation

protocol EventPersistence {
    func load() -> [Event]
    func snapshot() -> [Event]
    func insert(_ event: Event) throws
    func remove(id: UUID)
}

extension EventPersistence {
    func snapshot() -> [Event] {
        return load()
    }
}

final class UserDefaultsEventPersistence: EventPersistence {
    private let storageKeyPrefix = "com.pushpushgo.push.events.v1."
    private let legacyStorageKey = "SavedPPGEvents"
    private let eventExpirationTimeout: TimeInterval = 7 * 24 * 60 * 60

    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.custom.string(from: date))
        }

        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            guard let date = ISO8601DateFormatter.custom.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }

            return date
        }
    }

    func load() -> [Event] {
        migrateLegacyEventsIfNeeded()
        return snapshot()
    }

    func snapshot() -> [Event] {
        return SharedData.shared.sharedDefaults.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix(storageKeyPrefix), let data = value as? Data else {
                return nil
            }

            return try? decoder.decode(Event.self, from: data)
        }
    }

    func insert(_ event: Event) throws {
        let data = try encoder.encode(event)
        SharedData.shared.sharedDefaults.set(data, forKey: storageKey(for: event.id))
    }

    func remove(id: UUID) {
        SharedData.shared.sharedDefaults.removeObject(forKey: storageKey(for: id))
    }

    private func migrateLegacyEventsIfNeeded() {
        let defaults = SharedData.shared.sharedDefaults
        guard let data = defaults.data(forKey: legacyStorageKey) else { return }

        let projectId = SharedData.shared.projectId
        let apiToken = SharedData.shared.apiToken
        let subscriberId = SharedData.shared.subscriberId
        guard !projectId.isEmpty, !apiToken.isEmpty, !subscriberId.isEmpty else {
            return
        }

        do {
            let legacyEvents = try decoder.decode([Event].self, from: data)
            let now = Date()

            for legacyEvent in legacyEvents where legacyEvent.sentAt == nil {
                guard let timestamp = Event.iso8601DateFormatter.date(from: legacyEvent.timestamp),
                      now.timeIntervalSince(timestamp) < eventExpirationTimeout else {
                    continue
                }

                let event = Event(
                    eventType: legacyEvent.eventType,
                    button: legacyEvent.button,
                    campaign: legacyEvent.campaign,
                    projectId: projectId,
                    apiToken: apiToken,
                    subscriberId: subscriberId,
                    timestamp: legacyEvent.timestamp
                )
                try insert(event)
            }

            defaults.removeObject(forKey: legacyStorageKey)
        } catch {
            print("PPG EventPersistence: Legacy migration failed: \(error)")
        }
    }

    private func storageKey(for id: UUID) -> String {
        return storageKeyPrefix + id.uuidString
    }
}

extension ISO8601DateFormatter {
    static let custom: ISO8601DateFormatter = Event.iso8601DateFormatter
}
