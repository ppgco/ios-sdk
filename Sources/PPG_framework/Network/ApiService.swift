//
//  ApiService.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 14/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

class ApiService {
    static var shared = ApiService()

    let baseUrl = "https://api.pushpushgo.com"
    private static let inactiveSubscriberMessage = "Cannot perform operation on inactive subscriber"

    func subscribeUser(token: String, handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let body = SubscribeUserRequest.make(token: token)

        guard let encoded = try? JSONEncoder().encode(body) else {
            let log = "Failed to encode token"
            print(log)
            handler(.error(log))
            return
        }

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                handler(.error(error.localizedDescription))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                handler(.error("Invalid response from server"))
                return
            }

            guard (200...299).contains(response.statusCode) else {
                handler(.error("Server returned HTTP \(response.statusCode)"))
                return
            }

            guard let data = data else {
                handler(.error("No data in response"))
                return
            }

            if let decodedData = try? JSONDecoder().decode(SubscribeUserResponse.self, from: data) {
                SharedData.shared.subscriberId = decodedData._id
                handler(.success)
            } else {
                let log = "Invalid response from server"
                print("❌ PPG SDK: \(log)")
                handler(.error(log))
            }
        }.resume()
    }

    func unsubscribeUser(handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.subscriberId

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber/\(subscriberId)")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                handler(.error(error.localizedDescription))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                handler(.error("Invalid response from server"))
                return
            }

            if (200...299).contains(response.statusCode) || response.statusCode == 404 {
                handler(.success)
                return
            }

            if response.statusCode == 400,
               let data = data,
               let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data),
               apiError.message == Self.inactiveSubscriberMessage {
                handler(.success)
                return
            }

            handler(.error("Server returned HTTP \(response.statusCode)"))
        }.resume()
    }

    func sendEvent(event: Event, handler: @escaping (_ result: EventSendResult) -> Void) {
        let bodyData = EventBody(
            type: event.eventType.rawValue,
            payload: EventBodyPayload(timestamp: event.timestamp, button: event.button,
                                      campaign: event.campaign, subscriber: event.subscriberId))

        guard let encoded = try? JSONEncoder().encode(bodyData) else {
            handler(.permanentFailure("Failed to encode event"))
            return
        }

        guard let url = URL(string: "\(baseUrl)/v1/ios/\(event.projectId)/event/") else {
            handler(.permanentFailure("Failed to construct event URL"))
            return
        }

        var request = URLRequest(url: url)
        request.addStandardHeaders(apiToken: event.apiToken)
        request.httpMethod = "POST"
        request.httpBody = encoded
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                handler(.platformFailure(error.localizedDescription))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                handler(.platformFailure("Invalid response from server"))
                return
            }

            guard (200...299).contains(response.statusCode) else {
                let message = "Server returned HTTP \(response.statusCode)"
                if response.statusCode == 408 || response.statusCode == 429
                    || (500...599).contains(response.statusCode) {
                    handler(.retryableFailure(message))
                } else {
                    handler(.permanentFailure(message))
                }
                return
            }

            handler(.success)
        }.resume()
    }

    func sendBeacon(beacon: Beacon, handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.subscriberId
        
        if subscriberId == "" {
            handler(.error("Subscriber ID is not available"))
            return
        }

        let requestBody = BeaconBody(beacon: beacon)

        guard let encoded = try? JSONEncoder().encode(requestBody) else {
            handler(.error("Failed to encode beacon"))
            return
        }

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber/\(subscriberId)/beacon")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                handler(.error(error.localizedDescription))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                handler(.error("Invalid response from server"))
                return
            }

            guard (200...299).contains(response.statusCode) else {
                handler(.error("Server returned HTTP \(response.statusCode)"))
                return
            }

            handler(.success)
        }.resume()
    }
}

private struct SubscribeUserRequest: Encodable {
    private static let currentSDKVersion = "4.5.0"

    let token: String
    let installationId: String
    let osVersion: String
    let sdkVersion: String

    static func make(token: String) -> SubscribeUserRequest {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return SubscribeUserRequest(
            token: token,
            installationId: SharedData.shared.installationId,
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            sdkVersion: currentSDKVersion
        )
    }
}
