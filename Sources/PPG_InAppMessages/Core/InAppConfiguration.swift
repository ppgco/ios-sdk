// InAppConfiguration.swift
// Configuration helper for In-App Messages SDK
// Reference: Android InAppConfiguration pattern

import Foundation

/// Configuration helper for In-App Messages SDK
public struct InAppConfiguration {
    
    /// API configuration
    public let apiKey: String
    public let projectId: String
    public let isProduction: Bool
    
    /// User configuration
    public var userId: String?
    
    /// Default configuration for production
    public static func production(apiKey: String, projectId: String) -> InAppConfiguration {
        return InAppConfiguration(
            apiKey: apiKey,
            projectId: projectId,
            isProduction: true
        )
    }
    
    /// Default configuration for staging/testing
    public static func staging(apiKey: String, projectId: String) -> InAppConfiguration {
        return InAppConfiguration(
            apiKey: apiKey,
            projectId: projectId,
            isProduction: false
        )
    }
    
    public init(apiKey: String, projectId: String, isProduction: Bool) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.isProduction = isProduction
    }
}

// MARK: - Integration Examples

/// Example integration patterns for common scenarios
public struct InAppIntegrationExamples {
    
    /// Basic setup in AppDelegate
    /// Reference: Android Application class integration
    public static func basicAppDelegateSetup() -> String {
        return """
        // AppDelegate.swift
        import UIKit
        import PPG_framework      // Push notifications SDK
        import PPG_InAppMessages  // In-App messages SDK

        @main
        class AppDelegate: UIResponder, UIApplicationDelegate {

            func application(_ application: UIApplication, 
                           didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
                
                // Initialize Push Notifications SDK first
                PushPushGo.shared.initialize(
                    apiKey: "your-api-key",
                    projectId: "your-project-id"
                )
                
                // Initialize In-App Messages SDK
                InAppMessagesSDK.shared.initialize(
                    apiKey: "your-api-key", 
                    projectId: "your-project-id",
                    isProduction: true
                )
                
                // Set user ID if available
                InAppMessagesSDK.shared.setUserId("user-123")
                
                return true
            }
        }
        """
    }
    
    /// ViewController integration
    /// Reference: Android Activity integration
    public static func viewControllerIntegration() -> String {
        return """
        // ViewController.swift
        import UIKit
        import PPG_InAppMessages

        class ViewController: UIViewController {

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                
                // Trigger in-app message check when view appears
                InAppMessagesSDK.shared.onViewControllerWillAppear(self)
            }
            
            override func viewDidDisappear(_ animated: Bool) {
                super.viewDidDisappear(animated)
                
                // Clean up when view disappears
                InAppMessagesSDK.shared.onViewControllerDidDisappear()
            }
            
            @IBAction func customEventButtonTapped(_ sender: UIButton) {
                // Show messages on custom trigger with key-value matching
                InAppMessagesSDK.shared.showMessagesOnTrigger(key: "event_type", value: "button_tap", viewController: self)
            }
        }
        """
    }
    
    /// Manual message refresh
    public static func manualRefresh() -> String {
        return """
        // Manual refresh example
        class SomeViewController: UIViewController {
            
            @IBAction func refreshMessagesButtonTapped(_ sender: UIButton) {
                Task {
                    await InAppMessagesSDK.shared.refreshActiveMessages(viewController: self)
                }
            }
        }
        """
    }
    
    /// SPM integration example
    public static func spmIntegration() -> String {
        return """
        // Package.swift - for apps using Swift Package Manager
        
        dependencies: [
            .package(url: "https://github.com/ppgco/ios-sdk.git", from: "3.0.5")
        ],
        targets: [
            .target(
                name: "YourApp",
                dependencies: [
                    .product(name: "PPG_framework", package: "ios-sdk"),        // Push notifications
                    .product(name: "PPG_InAppMessages", package: "ios-sdk")     // In-app messages
                ]
            )
        ]
        """
    }
    
    /// CocoaPods integration example
    public static func cocoapodsIntegration() -> String {
        return """
        # Podfile - for apps using CocoaPods
        
        platform :ios, '11.0'
        use_frameworks!
        
        target 'YourApp' do
          pod 'PPG_framework', '~> 3.0.5'        # Push notifications SDK
          pod 'PPG_InAppMessages', '~> 3.0.5'    # In-app messages SDK
        end
        """
    }
}
