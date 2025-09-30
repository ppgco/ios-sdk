// InAppLogger.swift
// Logger utility for PPG In-App Messages SDK
// Reference: Android Logger utilities

import Foundation
import os.log

/// Logger utility class for In-App Messages SDK
public class InAppLogger {
    
    static let shared = InAppLogger()
    
    private let osLog: OSLog
    private var isDebugEnabled: Bool
    
    private init() {
        self.osLog = OSLog(subsystem: "com.pushpushgo.inappmessages", category: "InAppMessagesSDK")
        self.isDebugEnabled = false // Default to false - no logs unless explicitly enabled
    }
    
    /// Enable or disable debug logging
    /// - Parameter enabled: true to enable debug logs, false to disable
    func setDebugEnabled(_ enabled: Bool) {
        isDebugEnabled = enabled
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String) {
        if isDebugEnabled {
            os_log("%@", log: osLog, type: .debug, message)
        }
    }
    
    func info(_ message: String) {
        if isDebugEnabled {
            os_log("%@", log: osLog, type: .info, message)
        }
    }
    
    func error(_ message: String) {
        if isDebugEnabled {
            os_log("%@", log: osLog, type: .error, message)
        }
    }
    
    func fault(_ message: String) {
        if isDebugEnabled {
            os_log("%@", log: osLog, type: .fault, message)
        }
    }
}
