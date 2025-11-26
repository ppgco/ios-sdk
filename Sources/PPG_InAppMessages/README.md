# PPG In-App Messages SDK for iOS

Display personalized in-app messages to your iOS app users with rich content, smart targeting, and beautiful templates.

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 13.0+

## Installation

### Swift Package Manager (Recommended)

In Xcode:
1. File → Add Package Dependencies...
2. Enter: `https://github.com/ppgco/ios-sdk`
3. Select `PPG_InAppMessages` product

### CocoaPods

```ruby
pod 'PPG_InAppMessages', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.0.1'
```

Then run:
```bash
pod install
```

## Quick Start

**3 simple steps to get started:**

1. **Initialize** the SDK in your App
2. **Call** `onRouteChanged()` when user navigates
3. **Done!** SDK handles everything else automatically

### SwiftUI Integration

```swift
import SwiftUI
import PPG_InAppMessages

@main
struct YourApp: App {
    init() {
        // Initialize SDK once at app launch
        InAppMessagesSDK.shared.initialize(
            apiKey: "YOUR_API_KEY",
            projectId: "YOUR_PROJECT_ID"
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

struct HomeView: View {
    var body: some View {
        VStack {
            Text("Home Screen")
            NavigationLink("Go to Products", destination: ProductsView())
        }
        .onAppear {
            InAppMessagesSDK.shared.onRouteChanged("home")
        }
    }
}

struct ProductsView: View {
    var body: some View {
        Text("Products")
            .onAppear {
                InAppMessagesSDK.shared.onRouteChanged("products")
            }
    }
}
```

### UIKit Integration

```swift
import UIKit
import PPG_InAppMessages

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize SDK once at app launch
        InAppMessagesSDK.shared.initialize(
            apiKey: "YOUR_API_KEY",
            projectId: "YOUR_PROJECT_ID"
        )
        
        return true
    }
}

class HomeViewController: UIViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        InAppMessagesSDK.shared.onRouteChanged("home")
    }
}

class ProductsViewController: UIViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        InAppMessagesSDK.shared.onRouteChanged("products")
    }
}
```

## Advanced Usage

### Custom Triggers

Display messages based on user actions (button click, purchase complete, level up, etc.):

```swift
// SDK automatically finds the view controller
InAppMessagesSDK.shared.showMessagesOnTrigger(
    key: "action",
    value: "purchase_complete"
)

InAppMessagesSDK.shared.showMessagesOnTrigger(
    key: "level",
    value: "10"
)

// For UIKit: optionally pass specific view controller
InAppMessagesSDK.shared.showMessagesOnTrigger(
    key: "action",
    value: "button_clicked",
    viewController: self
)
```

### Handle Custom Button Actions

Execute your own code when users click buttons with custom actions:

```swift
// Set handler during app initialization
InAppMessagesSDK.shared.setCustomCodeActionHandler { customCode in
    print("User clicked button with custom code: \(customCode)")
    
    // Example: Navigate to specific screen
    if customCode == "navigate_to_shop" {
        // Your navigation logic
    }
}
```

### Clear Cache

Useful for testing or forcing fresh data:

```swift
InAppMessagesSDK.shared.clearMessageCache()
```

## Production Examples

Looking for more examples? Check out **[Examples.md](Examples.md)** for more complex implementations:

- 🛒 **E-commerce**: Cart abandonment, promotional triggers
- 🎮 **Gaming**: Level completion, milestone celebrations
- 📰 **News/Content**: Category targeting, premium paywalls
- 🚀 **Onboarding**: Multi-step user guidance
- 🔗 **Deep Navigation**: Router integration, custom code handlers
- ⚡ **Limited Offers**: Flash sales, time-sensitive promos
- 🆕 **Feature Announcements**: App update notifications

[**→ View All Examples**](Examples.md)

## How It Works

### 1. Configure Messages in PPG Dashboard

Create and configure messages in your PushPushGo dashboard:

- **Templates:** Choose from Fullscreen, Modal, or Banner
- **Content:** Add images, text, buttons with actions (URL, Close, or Custom Code)
- **Display Rules:** "Show once", "Show after X seconds", or "Always show"
- **Targeting:** Specific routes (e.g., "home", "checkout"), user audience, devices
- **Triggers:** On route enter or custom trigger events

### 2. SDK Checks for Messages

The SDK automatically checks for eligible messages when:
- User navigates to a new screen (via `onRouteChanged`)
- Custom trigger fires (via `showMessagesOnTrigger`)
- Every 60 seconds (background timer)

### 3. Display Logic

Messages are displayed if they match:
- ✅ Current route (if route-based)
- ✅ Trigger key-value pair (if trigger-based)
- ✅ Display history (respects "show once" / "show after time" rules)
- ✅ User audience (all / subscribers / non-subscribers)
- ✅ Device and OS targeting

## Troubleshooting

### Messages not showing?

**1. Enable debug logging**
```swift
InAppMessagesSDK.shared.initialize(
    apiKey: "...",
    projectId: "...",
    isDebug: true  // Enable detailed logs
)
```

**2. Check route matches backend config**
- Route name in code must exactly match dashboard configuration
- Example: `onRouteChanged("home")` matches dashboard route "home"

**3. Clear cache when testing**
```swift
InAppMessagesSDK.shared.clearMessageCache()
```

**4. Verify display rules**
- Messages with "Show once" won't appear after being dismissed
- Messages with "Show after time" require waiting period
- Check that message is enabled in dashboard

**5. Check targeting**
- Verify user audience matches (subscribers vs non-subscribers)
- Confirm device and OS targeting includes iOS

### No warnings or errors?

The SDK is designed to work seamlessly with both UIKit and SwiftUI. It automatically detects `UIHostingController` and adapts the view hierarchy.

## API Reference

### Essential Methods (For Most Apps)

```swift
// Initialize SDK (call once at app launch)
initialize(apiKey: String, projectId: String, isProduction: Bool = true, isDebug: Bool = false)

// Notify route change (SDK finds view controller automatically)
onRouteChanged(_ route: String)

// Trigger messages on custom events (SDK finds view controller automatically)
showMessagesOnTrigger(key: String, value: String)

// Handle custom button actions
setCustomCodeActionHandler(_ handler: @escaping (String) -> Void)

// Clear cache (useful for testing)
clearMessageCache()
```

### Advanced Methods (Optional Manual Control)

```swift
// Manually specify view controller (useful for complex UIKit navigation)
onViewControllerWillAppear(_ viewController: UIViewController)
onViewControllerDidDisappear()

// Custom trigger with specific view controller
showMessagesOnTrigger(key: String, value: String, viewController: UIViewController)

// Manually refresh messages
refreshActiveMessages(viewController: UIViewController)
```

## Support

For issues, feature requests, or questions:
- GitHub Issues: https://github.com/ppgco/ios-sdk/issues
- Documentation: https://docs.pushpushgo.com
