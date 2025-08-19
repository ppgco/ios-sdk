// InAppLogger.swift
// Logger utility for PPG In-App Messages SDK
// Reference: Android Logger utilities

import Foundation
import os.log

/// Logger utility class for In-App Messages SDK
public class InAppLogger {
    
    static let shared = InAppLogger()
    
    private let osLog: OSLog
    private let isDebugEnabled: Bool
    
    private init() {
        self.osLog = OSLog(subsystem: "com.pushpushgo.inappmessages", category: "InAppMessagesSDK")
        #if DEBUG
        self.isDebugEnabled = true
        #else
        self.isDebugEnabled = false
        #endif
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String) {
        if isDebugEnabled {
            os_log("%@", log: osLog, type: .debug, message)
        }
    }
    
    func info(_ message: String) {
        os_log("%@", log: osLog, type: .info, message)
    }
    
    func error(_ message: String) {
        os_log("%@", log: osLog, type: .error, message)
    }
    
    func fault(_ message: String) {
        os_log("%@", log: osLog, type: .fault, message)
    }
}
