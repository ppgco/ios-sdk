# In-App Messages - Real-World Examples

This document provides practical examples of how to use the PPG In-App Messages SDK in production apps.

## Table of Contents

- [Route-Based Display with Router Integration](#route-based-display-with-router-integration)
- [E-commerce: Cart Abandonment](#e-commerce-cart-abandonment)
- [Gaming: Level Completion](#gaming-level-completion)
- [News App: Content Categories](#news-app-content-categories)
- [Onboarding Flow](#onboarding-flow)
- [Custom Code Actions: Deep Navigation](#custom-code-actions-deep-navigation)
- [Limited Time Offers](#limited-time-offers)
- [Feature Announcements](#feature-announcements)

---

## Route-Based Display with Router Integration

Integrate with your app's navigation system to automatically display messages on route changes.

### SwiftUI with ObservableObject Router

```swift
import SwiftUI
import PPG_InAppMessages

// Router for app navigation
class AppRouter: ObservableObject {
    @Published var currentRoute: Route = .home
    
    enum Route: String {
        case home = "home"
        case products = "products"
        case productDetail = "product_detail"
        case cart = "cart"
        case checkout = "checkout"
        case profile = "profile"
    }
    
    func navigateTo(_ route: Route) {
        currentRoute = route
        
        // Automatically notify In-App Messages SDK
        InAppMessagesSDK.shared.onRouteChanged(route.rawValue)
        
        print("📍 Navigated to: \(route.rawValue)")
    }
}

// Usage in views
struct ContentView: View {
    @StateObject private var router = AppRouter()
    
    var body: some View {
        NavigationStack {
            Group {
                switch router.currentRoute {
                case .home:
                    HomeView(router: router)
                case .products:
                    ProductsView(router: router)
                case .productDetail:
                    ProductDetailView(router: router)
                case .cart:
                    CartView(router: router)
                case .checkout:
                    CheckoutView(router: router)
                case .profile:
                    ProfileView(router: router)
                }
            }
        }
        .onAppear {
            router.navigateTo(.home)
        }
    }
}

struct ProductsView: View {
    @ObservedObject var router: AppRouter
    
    var body: some View {
        VStack {
            Text("Products")
            
            Button("View iPhone 15") {
                router.navigateTo(.productDetail)
            }
        }
    }
}
```

### UIKit with Coordinator Pattern

```swift
import UIKit
import PPG_InAppMessages

protocol Coordinator {
    var navigationController: UINavigationController { get }
    func start()
}

class AppCoordinator: Coordinator {
    let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        showHome()
    }
    
    func showHome() {
        let homeVC = HomeViewController()
        homeVC.coordinator = self
        navigationController.pushViewController(homeVC, animated: true)
        
        // Notify SDK about route
        InAppMessagesSDK.shared.onRouteChanged("home")
    }
    
    func showProducts() {
        let productsVC = ProductsViewController()
        productsVC.coordinator = self
        navigationController.pushViewController(productsVC, animated: true)
        
        // Notify SDK about route
        InAppMessagesSDK.shared.onRouteChanged("products")
    }
    
    func showProductDetail(productId: String) {
        let detailVC = ProductDetailViewController(productId: productId)
        detailVC.coordinator = self
        navigationController.pushViewController(detailVC, animated: true)
        
        // Notify SDK about route
        InAppMessagesSDK.shared.onRouteChanged("product_detail")
        
        // Optional: Trigger with product ID
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "product_id",
            value: productId
        )
    }
}
```

**Dashboard Configuration:**
- Route: `products` - Show promotional banner
- Route: `product_detail` - Show related offers or upsells
- Route: `cart` - Show checkout incentives

---

## E-commerce: Cart Abandonment

Show a discount message when user views cart but doesn't checkout.

```swift
class CartViewController: UIViewController {
    var cartTotal: Decimal = 0
    var itemCount: Int = 0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Notify SDK about cart route
        InAppMessagesSDK.shared.onRouteChanged("cart")
        
        // Strategy 1: High-value cart discount
        if cartTotal > 100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                InAppMessagesSDK.shared.showMessagesOnTrigger(
                    key: "cart_value",
                    value: "high"
                )
            }
        }
        
        // Strategy 2: Cart abandonment reminder
        if itemCount > 0 {
            scheduleAbandonmentReminder()
        }
    }
    
    private func scheduleAbandonmentReminder() {
        // If user doesn't checkout in 30 seconds, show reminder
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            guard let self = self,
                  self.isViewLoaded && self.view.window != nil else { return }
            
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "cart_status",
                value: "abandoned"
            )
        }
    }
    
    @IBAction func checkoutButtonTapped(_ sender: UIButton) {
        // Navigate to checkout
        coordinator?.showCheckout()
    }
}
```

**Dashboard Configuration:**
- **High-value cart:**
  - Display: Custom trigger
  - Trigger: `cart_value: high`
  - Message: "🎉 Get 10% off orders over $100! Use code: SAVE10"
  - Button: Apply Discount (custom code: `apply_discount_10`)

- **Abandoned cart:**
  - Display: Custom trigger
  - Trigger: `cart_status: abandoned`
  - Message: "Don't forget your items! Complete checkout now 🛒"
  - Display rules: Show once per session

---

## Gaming: Level Completion

Congratulate users and promote premium features.

```swift
class GameEngine {
    weak var delegate: GameEngineDelegate?
    
    func completeLevel(_ level: Int) {
        // Save progress
        GameProgress.shared.saveCompletedLevel(level)
        
        // Show completion animation
        delegate?.showLevelCompletionAnimation(level)
        
        // Trigger in-app message
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "level_complete",
            value: "\(level)"
        )
        
        // Milestone achievements (every 10 levels)
        if level % 10 == 0 {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "milestone",
                value: "level_\(level)"
            )
        }
        
        // Promote premium after level 5
        if level == 5 && !PremiumManager.shared.isPremium {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "premium_promo",
                value: "level_5"
            )
        }
    }
}
```

**Dashboard Configuration:**
- **Milestone celebration:**
  - Display: Custom trigger
  - Trigger: `milestone: level_10`, `level_20`, `level_30`, etc.
  - Message: "🎉 Amazing! Level 10 completed! You're in the top 20% of players!"
  - Button: Share Achievement (custom code: `share_milestone`)

- **Premium promotion:**
  - Display: Custom trigger
  - Trigger: `premium_promo: level_5`
  - Message: "Unlock 100+ exclusive levels! Go Premium for $4.99"
  - Button: Upgrade Now (custom code: `open_premium`)

---

## News App: Content Categories

Show relevant subscription offers based on content type.

```swift
struct ArticleView: View {
    let article: Article
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(article.title)
                    .font(.title)
                
                if article.isPremium && !subscriptionManager.isSubscribed {
                    PremiumContentOverlay()
                }
                
                Text(article.content)
                    .font(.body)
            }
            .padding()
        }
        .onAppear {
            trackArticleView()
        }
    }
    
    private func trackArticleView() {
        // Track article route
        InAppMessagesSDK.shared.onRouteChanged("article")
        
        // Category-specific messages
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "category",
            value: article.category // "sports", "business", "tech", etc.
        )
        
        // Premium content paywall
        if article.isPremium && !subscriptionManager.isSubscribed {
            // Delay to let user see preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                InAppMessagesSDK.shared.showMessagesOnTrigger(
                    key: "content_type",
                    value: "premium"
                )
            }
        }
        
        // Frequent reader promotion
        if UserAnalytics.shared.articlesReadToday > 5 {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "reader_type",
                value: "frequent"
            )
        }
    }
}
```

**Dashboard Configuration:**
- **Premium paywall:**
  - Display: Custom trigger
  - Trigger: `content_type: premium`
  - Message: "📰 Unlimited premium articles for $9.99/month"
  - Button: Subscribe (custom code: `open_subscription`)

- **Category promotion:**
  - Display: Custom trigger
  - Trigger: `category: sports`
  - Message: "⚽ Love sports? Get real-time alerts for your favorite teams!"
  - Button: Enable Alerts (action: subscribe)

---

## Onboarding Flow

Guide new users through app features with contextual messages.

```swift
struct OnboardingView: View {
    @State private var currentStep = 0
    let totalSteps = 4
    
    var body: some View {
        TabView(selection: $currentStep) {
            WelcomeStep()
                .tag(0)
                .onAppear { 
                    InAppMessagesSDK.shared.onRouteChanged("onboarding_welcome") 
                }
            
            FeaturesStep()
                .tag(1)
                .onAppear { 
                    InAppMessagesSDK.shared.onRouteChanged("onboarding_features")
                    
                    // Show feature highlight message
                    InAppMessagesSDK.shared.showMessagesOnTrigger(
                        key: "onboarding_step",
                        value: "features"
                    )
                }
            
            PermissionsStep()
                .tag(2)
                .onAppear { 
                    InAppMessagesSDK.shared.onRouteChanged("onboarding_permissions") 
                }
            
            CompletionStep()
                .tag(3)
                .onAppear {
                    InAppMessagesSDK.shared.onRouteChanged("onboarding_complete")
                    
                    // Mark onboarding complete
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    
                    // Show welcome offer
                    InAppMessagesSDK.shared.showMessagesOnTrigger(
                        key: "onboarding_status",
                        value: "completed"
                    )
                }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

**Dashboard Configuration:**
- **Permissions step:**
  - Route: `onboarding_permissions`
  - Message: "📲 Enable notifications to never miss important updates!"
  - Button: Enable Notifications (action: subscribe)

- **Welcome offer:**
  - Display: Custom trigger
  - Trigger: `onboarding_status: completed`
  - Message: "🎉 Welcome aboard! Get 20% off your first purchase with code WELCOME20"
  - Display rules: Show once

---

## Custom Code Actions: Deep Navigation

Handle complex navigation and actions from in-app message buttons.

```swift
// In AppDelegate or main App initialization
func setupInAppMessagesHandlers() {
    InAppMessagesSDK.shared.setCustomCodeActionHandler { customCode in
        
        switch customCode {
        case "open_premium_subscription":
            // Navigate to subscription screen
            NotificationCenter.default.post(
                name: .navigateToSubscription,
                object: nil,
                userInfo: ["source": "in_app_message"]
            )
            
        case "open_special_offer":
            // Open specific product with pre-applied discount
            NotificationCenter.default.post(
                name: .openProductOffer,
                object: ProductOffer(
                    productId: "summer_2024",
                    discountCode: "SUMMER50",
                    discountPercent: 0.5
                )
            )
            
        case "start_tutorial":
            // Launch interactive tutorial
            TutorialCoordinator.shared.startTutorial(type: .interactive)
            
        case "contact_support":
            // Open support chat with context
            SupportManager.shared.openChat(
                topic: "in_app_inquiry",
                metadata: ["source": "in_app_message"]
            )
            
        case "enable_notifications":
            // Request notification permissions
            NotificationPermissionManager.shared.requestPermission { granted in
                if granted {
                    print("✅ Notifications enabled")
                } else {
                    // Show settings prompt
                    self.showNotificationSettingsAlert()
                }
            }
            
        case "share_app":
            // Open share sheet
            ShareManager.shared.shareApp(source: "in_app_message")
            
        case "rate_app":
            // Open App Store rating
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
            
        case let code where code.starts(with: "open_url:"):
            // Handle dynamic URL opening
            let url = String(code.dropFirst("open_url:".count))
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
            
        default:
            print("⚠️ Unknown custom code: \(customCode)")
            // Log to analytics
            AnalyticsManager.shared.logEvent("unknown_custom_code", parameters: ["code": customCode])
        }
    }
}
```

**Dashboard Configuration Examples:**
- Button with custom code: `open_premium_subscription`
- Button with custom code: `start_tutorial`
- Button with custom code: `contact_support`
- Button with custom code: `open_url:https://example.com/promo`

---

## Limited Time Offers

Show flash sale or time-sensitive promotional messages.

```swift
struct HomeView: View {
    @StateObject private var promotionManager = PromotionManager.shared
    
    var body: some View {
        ScrollView {
            VStack {
                // Home content
                ProductGridView()
            }
        }
        .onAppear {
            handleHomeViewAppear()
        }
    }
    
    private func handleHomeViewAppear() {
        // Notify route change
        InAppMessagesSDK.shared.onRouteChanged("home")
        
        // Check for active promotions
        if let activePromo = promotionManager.activePromotion {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "promotion",
                value: activePromo.type.rawValue
            )
        }
        
        // Flash sale (time-limited)
        if promotionManager.isFlashSaleActive {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "promotion",
                value: "flash_sale"
            )
        }
        
        // Weekend special
        if Calendar.current.isDateInWeekend(Date()) {
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "promotion",
                value: "weekend_special"
            )
        }
        
        // First-time visitor offer
        if !UserDefaults.standard.bool(forKey: "has_visited_home") {
            UserDefaults.standard.set(true, forKey: "has_visited_home")
            
            InAppMessagesSDK.shared.showMessagesOnTrigger(
                key: "user_type",
                value: "first_visit"
            )
        }
    }
}

class PromotionManager: ObservableObject {
    static let shared = PromotionManager()
    
    @Published var activePromotion: Promotion?
    
    var isFlashSaleActive: Bool {
        // Check if current time is within flash sale window
        guard let promo = activePromotion,
              promo.type == .flashSale,
              promo.endDate > Date() else {
            return false
        }
        return true
    }
}
```

**Dashboard Configuration:**
- **Flash sale:**
  - Display: Custom trigger
  - Trigger: `promotion: flash_sale`
  - Display rules: Show after 2 seconds
  - Message: "⚡ Flash Sale! 50% off everything for the next 2 hours!"
  - Button: Shop Now (custom code: `open_flash_sale`)

- **First-time visitor:**
  - Display: Custom trigger
  - Trigger: `user_type: first_visit`
  - Display rules: Show once
  - Message: "🎁 Welcome! Get 15% off your first order with code WELCOME15"

---

## Feature Announcements

Show new feature announcements to users after app updates.

```swift
// In main app initialization or root view
func checkForFeatureAnnouncements() {
    let lastVersion = UserDefaults.standard.string(forKey: "lastAppVersion")
    let currentVersion = Bundle.main.appVersion
    
    if lastVersion != currentVersion {
        // New version detected
        print("📱 App updated from \(lastVersion ?? "unknown") to \(currentVersion)")
        
        // Notify route (usually home)
        InAppMessagesSDK.shared.onRouteChanged("home")
        
        // Trigger version-specific announcement
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "app_update",
            value: currentVersion
        )
        
        // Generic "what's new" message for all updates
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "update_status",
            value: "new_version"
        )
        
        // Save current version
        UserDefaults.standard.set(currentVersion, forKey: "lastAppVersion")
    }
}

// Usage in SwiftUI
struct MainAppView: View {
    var body: some View {
        ContentView()
            .onAppear {
                checkForFeatureAnnouncements()
            }
    }
}

// Usage in UIKit
class MainViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkForFeatureAnnouncements()
    }
}
```

**Dashboard Configuration:**
- **Version-specific announcement:**
  - Display: Custom trigger
  - Trigger: `app_update: 2.5.0` (match your version)
  - Message: "🎉 New in v2.5.0: Dark mode, offline reading, and faster sync!"
  - Display rules: Show once
  - Button: Learn More (custom code: `open_whats_new`)

- **Generic update message:**
  - Display: Custom trigger
  - Trigger: `update_status: new_version`
  - Message: "✨ App updated! Check out what's new"
  - Display rules: Show once per version

---

## Tips for Production Use

### 1. Combine Route and Trigger Logic
```swift
// Smart combination: route for context, trigger for specific condition
InAppMessagesSDK.shared.onRouteChanged("checkout")

if cartTotal > 200 {
    InAppMessagesSDK.shared.showMessagesOnTrigger(
        key: "cart_tier",
        value: "premium"
    )
}
```

### 2. Conditional Triggers Based on User Behavior
```swift
// Wait for user interaction before triggering
// Example: Show help message if user is idle
var userActivityTimer: Timer?

func resetActivityTimer() {
    userActivityTimer?.invalidate()
    userActivityTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
        // User hasn't interacted for 30 seconds
        InAppMessagesSDK.shared.showMessagesOnTrigger(
            key: "user_state",
            value: "idle"
        )
    }
}

```

**Note:** For simple time-based delays, use the dashboard's "Show after X seconds" setting instead of code delays.

### 3. Track Message Performance
```swift
// Log when messages should appear
InAppMessagesSDK.shared.showMessagesOnTrigger(
    key: "event",
    value: "purchase_complete"
)

AnalyticsManager.shared.logEvent("in_app_message_triggered", parameters: [
    "trigger_key": "event",
    "trigger_value": "purchase_complete"
])
```

### 4. Handle Edge Cases
```swift
// Check conditions before triggering
guard UserSession.shared.isLoggedIn else { return }
guard NetworkMonitor.shared.isConnected else { return }

InAppMessagesSDK.shared.showMessagesOnTrigger(
    key: "user_action",
    value: "premium_feature"
)
```

---

## Need More Help?

- [Main README](README.md) - Integration guide and API reference
- [GitHub Issues](https://github.com/ppgco/ios-sdk/issues) - Report bugs or request features
- [Documentation](https://docs.pushpushgo.com) - Full platform documentation
