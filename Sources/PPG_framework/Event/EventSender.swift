import Foundation

enum EventSendResult {
    case success
    case platformFailure(String)
    case retryableFailure(String)
    case permanentFailure(String)
}

protocol EventSender {
    func send(event: Event, handler: @escaping (_ result: EventSendResult) -> Void)
}

class DefaultEventSender: EventSender {
    func send(event: Event, handler: @escaping (_ result: EventSendResult) -> Void) {
        ApiService.shared.sendEvent(event: event, handler: handler)
    }
}
