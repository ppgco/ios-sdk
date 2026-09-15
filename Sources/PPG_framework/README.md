# PushPushGo Push Notifications SDK for iOS

> [!NOTE]
> **Version 4.5.0 is available.** It improves statistics reporting and notification processing. See the [changelog](CHANGELOG.md) for full details and migration notes.

## Requirements

- iOS 13.0+

## Installation

Before you start, make sure to remove all previous integrations with other providers.

### Swift Package Manager (recommended)

1. In Xcode, go to File → Add Package Dependencies…
2. Enter `https://github.com/ppgco/ios-sdk`
3. Select the `PPG_framework` product and add it to the app target.

### CocoaPods

In your Podfile, add:

```ruby
target 'YourApp' do
  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.5.0'
end
```

Replace `YourApp` with the name of your app target.

Then run:

```bash
pod install
```

### Migrating from CocoaPods to Swift Package Manager

1. If the PushPushGo iOS SDK was the only library installed by Pods, run `pod deintegrate` to remove any Pods-related files. If you are using Pods for any other dependencies, remove `PPG_framework` references manually and detach it from the app and Notification Service Extension targets.
2. In Xcode, go to File → Add Package Dependencies…, enter the GitHub URL above, and add `PPG_framework` to the app target.
3. Add `PPG_framework` to the Notification Service Extension target.
4. Clean and rebuild the project.
5. If you encounter derived data problems, remove the project's derived data in Xcode, restart Xcode, then clean and rebuild the project.

## Project setup

### Create and upload an APNs certificate

Upload the APNs certificate to your PushPushGo project by following the [APNs setup tutorial](https://docs.pushpushgo.company/application/providers/mobile-push/apns).

### Add required capabilities

1. Select the project in Xcode's Project navigator, then select the app under `TARGETS`.
2. Open the `Signing & Capabilities` tab.
3. Click `+ Capability` and add `Push Notifications`.
4. Click `+ Capability` again, add `App Groups`, and select an existing group or create a new one.
5. Make sure the provisioning profile includes these capabilities, then refresh it in Xcode.

> **How to add new group to your provisioning profile?**
>
> In the Apple Developer portal, navigate to *Certificates, Identifiers & Profiles*. Open *Identifiers*, change *App IDs* to *App Groups*, and create the group.
>
> Return to *Identifiers*, choose the app identifier, enable the App Groups capability, and select the new group.

### Create a Notification Service Extension

1. In Xcode, go to `File → New → Target`.
2. Select `Notification Service Extension` and click `Next`.
3. Enter a product name, for example `PPGNotificationServiceExtension`, select Swift as the language, and click `Finish`.
4. If Xcode asks whether to activate the new scheme, select `Activate`.
5. Select the new extension target and open `Signing & Capabilities`.
6. Click `+ Capability`, add `App Groups`, and select the exact same App Group used by the app target.
7. Add `PPG_framework` to the extension target:
   - **Swift Package Manager:** Under `General → Frameworks and Libraries`, click `+` and select `PPG_framework`.
   - **CocoaPods:** Add the extension target to your Podfile as shown below.
8. Open the generated `NotificationService.swift` file and replace its contents with the code below.
9. Replace `YOUR_APP_GROUP_ID` with the App Group identifier selected for both the app and extension targets.

```swift
import UserNotifications
import PPG_framework

class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        self.contentHandler = contentHandler
        self.bestAttemptContent = content

        // Set the App Group identifier configured for the app and extension.
        SharedData.shared.appGroupId = "YOUR_APP_GROUP_ID"

        let group = DispatchGroup()

        group.enter()
        PPG.notificationDelivered(notificationRequest: request) { _ in
            group.leave()
        }

        group.enter()
        PPG.modifyNotification(content) {
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self,
                  let contentHandler = self.contentHandler,
                  let bestAttemptContent = self.bestAttemptContent else {
                return
            }

            self.contentHandler = nil
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler = contentHandler,
              let bestAttemptContent = bestAttemptContent else {
            return
        }

        self.contentHandler = nil
        contentHandler(bestAttemptContent)
    }
}
```

#### CocoaPods integration

If you use CocoaPods, add the Notification Service Extension next to your application target in the Podfile. Replace `PPGNotificationServiceExtension` with the name you selected:

```ruby
target 'PPGNotificationServiceExtension' do
  use_frameworks!
  use_modular_headers!

  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.5.0'
end
```

If compiling the app with the Service Extension produces a problem with `UIApplication.shared`, add this at the end of the Podfile:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless target.name == 'PPG_framework'

    target.build_configurations.each do |config|
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
    end
  end
end
```

After updating the Podfile, run `pod install`.

## App integration

> [!NOTE]
> While the previous integration method (manually implementing all AppDelegate notification methods) will continue to work,
> we recommend switching to one of the new integration methods below. The new methods provide automatic notification handling
> and significantly reduce the amount of boilerplate code needed (SwiftUI).

The SDK supports three integration methods:

### 1. SwiftUI apps without an AppDelegate

For SwiftUI apps that don't have a custom AppDelegate:

```swift
import SwiftUI
import PPG_framework

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(PPGAppDelegate.self) var appDelegate
    
    init() {
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Register for notifications when the view appears
                    PPG.registerForNotifications(application: UIApplication.shared) { result in
                        switch result {
                        case .success:
                            print("Successfully registered for notifications")
                        case .error(let message):
                            print("Failed to register for notifications: \(message)")
                        }
                    }
                }
        }
    }
}
```

### 2. UIKit apps inheriting from PPGAppDelegate

For UIKit apps that want to inherit push notification handling:

```swift
import UIKit
import PPG_framework

@main
class AppDelegate: PPGAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // First call super to set up the PPG delegate
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
        
        // Register for notifications
        PPG.registerForNotifications(application: application) { result in
            switch result {
            case .success:
                print("Successfully registered for notifications")
            case .error(let message):
                print("Failed to register for notifications: \(message)")
            }
        }
        
        // Your additional setup code
        return result
    }
}
```

### 3. UIKit apps with an existing AppDelegate

For UIKit apps that already have an AppDelegate:

```swift
import UIKit
import PPG_framework

@main
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
        
        // Set up the PPG notification delegate
        PPGUserNotificationCenterDelegateSetUp()
        
        // Register for notifications
        PPG.registerForNotifications(application: application) { result in
            switch result {
            case .success:
                print("Successfully registered for notifications")
            case .error(let message):
                print("Failed to register for notifications: \(message)")
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PPGdidRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
}
```

## Usage

### Create and send a beacon

```swift
let beacon = Beacon()
beacon.addSelector("Test_Selector", "0")

// Methods with strategy and ttl support
// For append tag in concrete category (with ttl, default = 0)
beacon.appendTag("mytag", "mycategory")
beacon.appendTag("mytag", "mycategory", 3600)

// For rewrite tag in concrete category (with ttl, default = 0)
beacon.rewriteTag("mytag", "mycategory")
beacon.rewriteTag("mytag", "mycategory", 3600)

// For delete tag in concrete category (with ttl, default = 0)
beacon.deleteTag("mytag", "mycategory");

// Legacy methods (not supports strategy append/rewrite and ttl)
beacon.addTag("new_tag", "new_tag_label")
beacon.addTagToDelete(BeaconTag(tag: "my_old_tag", label: "my_old_tag_label"))

beacon.send() { result in }
```

### Dynamic Groups (Segments)

Assign or unassign subscribers to dynamic groups for targeted push notifications:

```swift
let beacon = Beacon()
beacon.customId = "user-xyz"

// Assign subscriber to a group
beacon.assignToGroup("premium-users")  // groupId

// Unassign subscriber from a group
beacon.unassignFromGroup("trial-users")  // groupId

beacon.send { result in }
```

### Unsubscribe user

`PPG.unsubscribeUser { result in ... }`

### Interactive notifications

The SDK supports interactive notifications with action buttons. Actions are configured through the notification payload and automatically managed by the SDK:

- Buttons are created dynamically based on the payload
- Duplicate button titles are handled automatically
- Categories expire after 7 days
- URLs can be associated with specific buttons

Button identifiers:

- `button_1`: First action button
- `button_2`: Second action button

Supported button options:

- `foreground`: Opens the app
- `destructive`: Red button style
- `authenticationRequired`: Requires device unlock

The SDK automatically manages:

- Category creation and registration
- Button title uniqueness
- Action handling and URL redirection
- Event tracking for button clicks

## Support

For issues, feature requests, or questions:

- GitHub Issues: https://github.com/ppgco/ios-sdk/issues
- Documentation: https://docs.pushpushgo.com
