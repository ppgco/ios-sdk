import Foundation
import UIKit

// Custom view that sets shadowPath for better shadow performance
private class ShadowContainerView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update shadow path to match the view's bounds for better performance
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}

/// InAppMessageDisplayer handles the UI presentation logic and coordinates with template views
internal class InAppMessageDisplayer {
    
    // Properties
    private let tag = "InAppMessageDisplayer"
    
    // Callbacks
    private let onMessageDismissed: () -> Void
    private let onMessageEvent: (String, InAppMessage, Int?) -> Void
    private var pushNotificationSubscriber: PushNotificationSubscriber
    
    // Custom code action handler (optional)
    private var customCodeActionHandler: ((String) -> Void)?
    
    // Current display state
    private var currentMessageView: UIView?
    private var currentViewController: UIViewController?
    private var overlayView: UIView?
    private var currentMessage: InAppMessage?
    
    // State management
    private var isDismissing = false
    
    // Template Types
    private enum TemplateType {
        case fullscreen  // Template 1
        case desktop     // Template 2 
        case horizontal  // Template 3
        
        static func from(_ template: String?) -> TemplateType {
            guard let template = template else { return .desktop }
            
            switch template.uppercased() {
            // Template 1 - Fullscreen (image 50% top, content 50% bottom)
            case "WEBSITE_TO_HOME_SCREEN", "PAYWALL_PUBLISH":
                return .fullscreen
                
            // Template 2 - Desktop Modal (centered card with image and content)
            case "EXIT_INTENT_ECOMM", "PUSH_NOTIFICATION_OPT_IN", "EXIT_INTENT_TRAVEL", 
                 "UNBLOCK_NOTIFICATIONS", "LOW_STOCK":
                return .desktop
                
            // Template 3 - Horizontal Banner (image left, content right)
            case "REVIEW_FOR_DISCOUNT":
                return .horizontal
                
            default: return .desktop
            }
        }
    }
    
    // Initialization
    
    init(
        onMessageDismissed: @escaping () -> Void,
        onMessageEvent: @escaping (String, InAppMessage, Int?) -> Void,
        pushNotificationSubscriber: PushNotificationSubscriber
    ) {
        self.onMessageDismissed = onMessageDismissed
        self.onMessageEvent = onMessageEvent
        self.pushNotificationSubscriber = pushNotificationSubscriber
    }
    
    // Public Methods
    
    /// Set handler for custom code actions
    /// This allows the app to handle custom code calls from action buttons
    /// - Parameter handler: Function that takes custom code string and processes it
    func setCustomCodeActionHandler(_ handler: @escaping (String) -> Void) {
        self.customCodeActionHandler = handler
    }
  
    func setCustomPushNotificationSubscriber(_ subscriber: PushNotificationSubscriber) {
      self.pushNotificationSubscriber = subscriber
    }
    
    /// Show message using appropriate template
    func showMessage(_ message: InAppMessage, in viewController: UIViewController) {
        guard !isDismissing else { return }
        
        currentMessage = message
        currentViewController = viewController
        
        let templateType = TemplateType.from(message.template)
        InAppLogger.shared.debug("Showing message \(message.id)")
        
        // Create message view using appropriate template
        let messageView = createTemplateView(for: message, templateType: templateType)
        messageView.clipsToBounds = true
        
        // Handle drop shadow with wrapper pattern
        let finalView: UIView
        if message.style.dropShadow {
            // Create shadow container that wraps messageView
            let shadowContainer = ShadowContainerView()
            shadowContainer.translatesAutoresizingMaskIntoConstraints = false
            shadowContainer.clipsToBounds = false // Allow shadows to extend beyond bounds
            shadowContainer.backgroundColor = UIColor.clear // Required for shadow rendering
            
            // Add shadow to container
            shadowContainer.layer.shadowColor = UIColor.black.cgColor
            shadowContainer.layer.shadowOffset = CGSize(width: 10, height: 15)
            shadowContainer.layer.shadowRadius = 20
            shadowContainer.layer.shadowOpacity = 0.33
            shadowContainer.layer.masksToBounds = false
            shadowContainer.layer.shouldRasterize = false
            
            // Add messageView to shadow container
            shadowContainer.addSubview(messageView)
            messageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                messageView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
                messageView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
                messageView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
                messageView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor)
            ])
            
            finalView = shadowContainer
        } else {
            finalView = messageView
        }
        
        currentMessageView = finalView
        
        // Add close button if enabled
        if message.style.closeIcon {
            addCloseButton(to: messageView, style: message.style)
        }
        
        // Determine the correct container view to avoid SwiftUI warnings
        let containerView = getContainerView(for: viewController)
        let isUsingWindow = containerView !== viewController.view
        
        // Add final view (either messageView or shadowContainer) to container
        containerView.addSubview(finalView)
        
        // ALWAYS setup tap area (overlay or invisible) to allow dismissal
        // When overlay is disabled, use invisible tap area for outside clicks
        setupOverlay(in: containerView, below: finalView, visible: message.style.overlay)
        
        // Apply zIndex from style
        finalView.layer.zPosition = CGFloat(message.style.zIndex)
        
        // Setup constraints - use container view for SwiftUI, viewController for UIKit
        if isUsingWindow {
            setupTemplateConstraintsForWindow(finalView, in: containerView, templateType: templateType)
        } else {
            setupTemplateConstraints(finalView, in: viewController, templateType: templateType)
        }
        
        // Setup action button targets
        setupActionTargets(in: messageView)
        
        // Animate in based on animationType
        if message.style.animationType == "appear" {
            // Appear animation
            messageView.alpha = 0
            messageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            
            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseOut) {
                messageView.alpha = 1
                messageView.transform = .identity
                self.overlayView?.alpha = 1
            }
        } else {
            // No animation - just appear instantly
            messageView.alpha = 1
            messageView.transform = .identity
            self.overlayView?.alpha = 1
        }
        
        // Dispatch show event
        onMessageEvent("show", message, nil)
    }
    
    /// Dismiss message (public interface)
    func dismissMessage() {
        dismissMessageInternal(sendCloseEvent: true)
    }
    
    /// Dismiss message silently (no close event)
    func dismissMessageSilently() {
        dismissMessageInternal(sendCloseEvent: false)
    }
    
    // Template System
    
    /// Create message view using appropriate template
    private func createTemplateView(for message: InAppMessage, templateType: TemplateType) -> UIView {
        switch templateType {
        case .fullscreen:
            return Template1FullscreenView.createView(for: message)
        case .desktop:
            return Template2DesktopView.createView(for: message)
        case .horizontal:
            return Template3HorizontalView.createView(for: message)
        }
    }
    
    /// Add close button overlay to any template
    private func addCloseButton(to messageView: UIView, style: MessageStyle) {
        let closeButton = SharedUIComponents.createCloseButton(style: style)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: UIControl.Event.touchUpInside)
        
        messageView.addSubview(closeButton)
        
        guard let message = currentMessage else { return }
        
        // Position close button at the corner, only accounting for border width
        let borderWidth = message.style.border ? CGFloat(message.style.borderWidth) : 0
        
        // Small offset to keep button inside the border, stable regardless of button size
        let offset = borderWidth + 2
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: messageView.topAnchor, constant: offset),
            closeButton.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -offset)
        ])
    }
    
    /// Setup constraints using template-specific methods
    private func setupTemplateConstraints(_ messageView: UIView, in viewController: UIViewController, templateType: TemplateType) {
        guard let message = currentMessage else { return }
        
        switch templateType {
        case .fullscreen:
            Template1FullscreenView.setupConstraints(messageView, in: viewController)
        case .desktop:
            Template2DesktopView.setupConstraints(messageView, in: viewController, placement: message.layout.placement, marginString: message.layout.margin)
        case .horizontal:
            Template3HorizontalView.setupConstraints(messageView, in: viewController, placement: message.layout.placement, marginString: message.layout.margin)
        }
    }
    
    /// Setup constraints for window-based layout (SwiftUI compatibility)
    private func setupTemplateConstraintsForWindow(_ messageView: UIView, in window: UIView, templateType: TemplateType) {
        guard let message = currentMessage else { return }
        messageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Get screen dimensions and safe area
        let screenWidth = window.bounds.width
        let screenHeight = window.bounds.height
        let safeArea = window.safeAreaInsets
        
        var constraints: [NSLayoutConstraint] = []
        
        switch templateType {
        case .fullscreen:
            // Fullscreen - fill entire window with safe area
            constraints = [
                messageView.topAnchor.constraint(equalTo: window.topAnchor, constant: safeArea.top),
                messageView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: safeArea.left),
                messageView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -safeArea.right),
                messageView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -safeArea.bottom)
            ]
            
        case .desktop:
            // Desktop modal - centered with max width
            let maxWidth: CGFloat = 520
            let preferredWidth = min(maxWidth, screenWidth - 40)
            let margin: CGFloat = 15 + safeArea.top // Add safe area to margin
            
            constraints = [
                messageView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                messageView.widthAnchor.constraint(equalToConstant: preferredWidth)
            ]
            
            // Handle placement
            let placement = message.layout.placement.lowercased()
            if placement.contains("top") {
                constraints.append(messageView.topAnchor.constraint(equalTo: window.topAnchor, constant: margin))
            } else if placement.contains("bottom") {
                constraints.append(messageView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -(margin - safeArea.top + safeArea.bottom)))
            } else {
                // Center
                constraints.append(messageView.centerYAnchor.constraint(equalTo: window.centerYAnchor))
            }
            
        case .horizontal:
            // Horizontal - full width with placement (respecting safe area)
            constraints = [
                messageView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: safeArea.left),
                messageView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -safeArea.right)
            ]
            
            // Handle placement
            let placement = message.layout.placement.lowercased()
            if placement.contains("top") {
                constraints.append(messageView.topAnchor.constraint(equalTo: window.topAnchor, constant: safeArea.top))
            } else if placement.contains("bottom") {
                constraints.append(messageView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -safeArea.bottom))
            } else {
                // Center
                constraints.append(messageView.centerYAnchor.constraint(equalTo: window.centerYAnchor))
            }
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    /// Setup action button targets recursively
    private func setupActionTargets(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton, button.tag >= 0 {
                // This is an action button (has positive tag)
                button.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
            } else {
                // Recurse into subviews
                setupActionTargets(in: subview)
            }
        }
    }
    
    // Layout & Constraints
    
    /// Get the appropriate container view to avoid SwiftUI warnings
    /// - Returns: UIWindow if available and using SwiftUI, otherwise viewController.view
    private func getContainerView(for viewController: UIViewController) -> UIView {
        // Check if we're dealing with UIHostingController (SwiftUI)
        let isHostingController = String(describing: type(of: viewController)).contains("HostingController")
        
        if isHostingController, let window = viewController.view.window {
            // For SwiftUI, add to window to avoid hierarchy warnings
            InAppLogger.shared.debug("Using window container for SwiftUI compatibility")
            return window
        }
        
        // For UIKit, use viewController.view
        return viewController.view
    }
    
    /// Setup overlay view below the message (visible darkening or invisible tap area)
    /// - Parameters:
    ///   - containerView: Container to add overlay to
    ///   - messageView: Message view to position below
    ///   - visible: If true, shows dark overlay (0.5 alpha). If false, invisible but still tappable
    private func setupOverlay(in containerView: UIView, below messageView: UIView, visible: Bool) {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = true // Enable touch events
        
        if visible {
            // Visible overlay - dark background
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            overlay.alpha = 0 // Start invisible for animation (will animate to 1)
        } else {
            // Invisible tap area - completely transparent but still captures taps
            overlay.backgroundColor = UIColor.clear
            overlay.alpha = 1 // Always visible (but transparent)
            InAppLogger.shared.debug("Using invisible tap area (overlay disabled)")
        }
        
        // Add tap gesture to dismiss on outside tap (silently - no close event)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlay.addGestureRecognizer(tapGesture)
        
        // Insert overlay below the message view
        containerView.insertSubview(overlay, belowSubview: messageView)
        
        // Set zPosition for overlay (one level below message)
        if let message = currentMessage {
            overlay.layer.zPosition = CGFloat(message.style.zIndex - 1)
        }
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        overlayView = overlay
    }
    
    // Action Handlers
    
    @objc private func closeButtonTapped() {
        guard let message = currentMessage else { return }
        onMessageEvent("close", message, nil)
        dismissMessageSilently()
    }
    
    @objc private func actionButtonTapped(_ sender: UIButton) {
        guard let message = currentMessage else { return }
        let actionIndex = sender.tag
        
        if actionIndex < message.actions.count {
            let action = message.actions[actionIndex]
            
            // Handle different action types - ALL button actions send "cta" event (like Android)
            if let actionType = ActionType(rawValue: action.actionType) {
                onMessageEvent("cta", message, actionIndex)
                
                switch actionType {
                case .redirect:
                    if let urlString = action.url, !urlString.isEmpty {
                        if let url = URL(string: urlString) {
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url) { success in
                                    if success {
                                        // Dismiss only after successful URL opening
                                        DispatchQueue.main.async {
                                            self.dismissMessageSilently()
                                        }
                                    } else {
                                        InAppLogger.shared.error("Failed to open URL")
                                    }
                                }
                                return // Don't dismiss immediately - wait for URL open result
                            } else {
                                InAppLogger.shared.error("Cannot open URL")
                            }
                        } else {
                            InAppLogger.shared.error("Invalid URL format")
                        }
                    } else {
                        InAppLogger.shared.error("REDIRECT action missing URL")
                    }
                case .close:
                    // CLOSE button action - just dismiss (cta event already sent above)
                    break
                case .subscribe:
                    handleSubscribeAction()
                    return // Don't dismiss yet - handleSubscribeAction will dismiss
                case .js:
                    if let customCode = action.call, !customCode.isEmpty {
                        handleCustomCodeAction(customCode)
                    } else {
                        InAppLogger.shared.error("Custom code action missing call")
                    }
                }
            } else {
                InAppLogger.shared.error("Invalid ActionType: \(action.actionType)")
            }
        } else {
            InAppLogger.shared.error("Action index out of bounds")
        }
        
        dismissMessageSilently()
    }
    
    @objc private func overlayTapped() {
        InAppLogger.shared.debug("Overlay tapped - dismissing silently (no close event)")
        dismissMessageSilently()
    }
    
    /// Handle subscribe action using bridge pattern
    private func handleSubscribeAction() {
        guard let viewController = currentViewController else { return }
        
        // Create status provider to check current subscription status
        let statusProvider = PushNotificationStatusProvider()
        
        // Check current subscription status
        let isSubscribed = statusProvider.isSubscribed()
        let isBlocked = statusProvider.isNotificationsBlocked()
        
        if isSubscribed && !isBlocked {
            // User is already fully subscribed
            showToast(message: "You are already subscribed to push notifications!")
            dismissMessageSilently()
            return
        } else if isBlocked {
            // Notifications are blocked at system level
            showToast(message: "Please enable notifications in Settings first.")
            dismissMessageSilently()
            return
        }
        
        Task {
            let success = await pushNotificationSubscriber.requestSubscription(viewController: viewController)
            
            DispatchQueue.main.async {
                // Show Toast message like Android
                self.showToast(message: success ? 
                    "Successfully subscribed to notifications!" : 
                    "Subscription failed. Enable notifications in settings.")
                
                self.dismissMessageSilently()
            }
        }
    }
    
    /// Handle custom code action by calling the provided handler
    private func handleCustomCodeAction(_ customCode: String) {
        if let handler = customCodeActionHandler {
            handler(customCode)
            InAppLogger.shared.debug("Custom code action executed")
        } else {
            InAppLogger.shared.debug("No custom code action handler provided")
        }
    }
    
    /// Show toast message (simple iOS implementation like Android Toast)
    private func showToast(message: String) {
        guard let viewController = currentViewController else { return }
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        viewController.present(alert, animated: true)
        
        // Auto dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alert.dismiss(animated: true)
        }
    }
    
    // Dismiss Methods
    
    /// Internal dismissal method with event control
    private func dismissMessageInternal(sendCloseEvent: Bool) {
        guard !isDismissing, let messageView = currentMessageView, let message = currentMessage else { return }
        
        isDismissing = true
        
        if sendCloseEvent {
            onMessageEvent("close", message, nil)
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            messageView.alpha = 0
            messageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.overlayView?.alpha = 0
        }) { _ in
            messageView.removeFromSuperview()
            self.overlayView?.removeFromSuperview()
            
            self.currentMessageView = nil
            self.overlayView = nil
            self.currentViewController = nil
            self.currentMessage = nil
            
            self.onMessageDismissed()
            self.isDismissing = false
        }
    }
}
