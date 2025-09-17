// InAppMessageDisplayer.swift
// Native iOS implementation of in-app message display using template system

import Foundation
import UIKit
import PPG_framework

// Custom view that sets shadowPath for better shadow performance
private class ShadowContainerView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update shadow path to match the view's bounds for better performance
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}

/// InAppMessageDisplayer handles the UI presentation logic and coordinates with template views
public class InAppMessageDisplayer {
    
    // MARK: - Properties
    private let tag = "InAppMessageDisplayer"
    
    // Callbacks
    private let onMessageDismissed: () -> Void
    private let onMessageEvent: (String, InAppMessage, Int?) -> Void
    private let subscriptionHandler: PushNotificationSubscriber
    
    // Current display state
    private var currentMessageView: UIView?
    private var currentViewController: UIViewController?
    private var overlayView: UIView?
    private var currentMessage: InAppMessage?
    
    // State management
    private var isDismissing = false
    
    // MARK: - Template Types
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
    
    // MARK: - Initialization
    
    public init(
        onMessageDismissed: @escaping () -> Void,
        onMessageEvent: @escaping (String, InAppMessage, Int?) -> Void,
        subscriptionHandler: PushNotificationSubscriber
    ) {
        self.onMessageDismissed = onMessageDismissed
        self.onMessageEvent = onMessageEvent
        self.subscriptionHandler = subscriptionHandler
    }
    
    // MARK: - Public Methods
    
    /// Show message using appropriate template
    public func showMessage(_ message: InAppMessage, in viewController: UIViewController) {
        guard !isDismissing else { return }
        
        currentMessage = message
        currentViewController = viewController
        
        let templateType = TemplateType.from(message.template)
        InAppLogger.shared.info("\(tag): 🎯 Showing message \(message.id) with template \(templateType)")
        
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
        
        // Setup overlay for modal templates
        if message.style.overlay {
            setupOverlay(in: viewController)
        }
        
        // Add final view (either messageView or shadowContainer) to view controller
        viewController.view.addSubview(finalView)
        
        // Apply zIndex from style
        finalView.layer.zPosition = CGFloat(message.style.zIndex)
        
        setupTemplateConstraints(finalView, in: viewController, templateType: templateType)
        
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
        
        InAppLogger.shared.info("\(tag): ✅ Message displayed successfully")
    }
    
    /// Dismiss message (public interface)
    public func dismissMessage() {
        dismissMessageInternal(sendCloseEvent: true)
    }
    
    /// Dismiss message silently (no close event)
    public func dismissMessageSilently() {
        dismissMessageInternal(sendCloseEvent: false)
    }
    
    // MARK: - Template System
    
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
        
        // For Template 1 (fullscreen), position relative to image section
        if let message = currentMessage, TemplateType.from(message.template) == .fullscreen {
            // Find the main stack and get the first arranged subview (image section)
            if let mainStack = findMainStack(in: messageView),
               let imageSection = mainStack.arrangedSubviews.first {
                NSLayoutConstraint.activate([
                    closeButton.topAnchor.constraint(equalTo: imageSection.topAnchor, constant: 10),
                    closeButton.trailingAnchor.constraint(equalTo: imageSection.trailingAnchor, constant: -10),
                    closeButton.widthAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth)),
                    closeButton.heightAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth))
                ])
            } else {
                // Fallback to messageView if we can't find the image section
                NSLayoutConstraint.activate([
                    closeButton.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 10),
                    closeButton.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -10),
                    closeButton.widthAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth)),
                    closeButton.heightAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth))
                ])
            }
        } else {
            // For other templates, position relative to messageView
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 10),
                closeButton.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -10),
                closeButton.widthAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth)),
                closeButton.heightAnchor.constraint(equalToConstant: CGFloat(style.closeIconWidth))
            ])
        }
    }
    
    /// Helper method to find the main stack in Template 1
    private func findMainStack(in view: UIView) -> UIStackView? {
        for subview in view.subviews {
            if let stackView = subview as? UIStackView,
               stackView.axis == .vertical,
               stackView.arrangedSubviews.count == 2 {
                return stackView
            }
        }
        return nil
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
    
    // MARK: - Layout & Constraints
    
    /// Setup overlay view
    private func setupOverlay(in viewController: UIViewController) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap gesture to dismiss on outside tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlay.addGestureRecognizer(tapGesture)
        
        viewController.view.insertSubview(overlay, at: 0)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        overlayView = overlay
    }
    
    // MARK: - Action Handlers
    
    @objc private func closeButtonTapped() {
        guard let message = currentMessage else { return }
        onMessageEvent("inapp.close", message, nil)
        dismissMessageSilently()
    }
    
    @objc private func actionButtonTapped(_ sender: UIButton) {
        guard let message = currentMessage else { return }
        let actionIndex = sender.tag
        
        InAppLogger.shared.info("\(tag): 🎯 Action tapped: \(actionIndex)")
        
        if actionIndex < message.actions.count {
            let action = message.actions[actionIndex]
            
            // Handle different action types
            if let actionType = ActionType(rawValue: action.actionType) {
                switch actionType {
                case .redirect:
                    onMessageEvent("inapp.cta", message, actionIndex)
                    if let urlString = action.url, let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                case .close:
                    onMessageEvent("inapp.close", message, actionIndex)
                case .subscribe:
                    onMessageEvent("inapp.subscribe", message, actionIndex)
                    handleSubscribeAction()
                    return // Don't dismiss yet - handleSubscribeAction will dismiss
                case .custom:
                    onMessageEvent("inapp.custom", message, actionIndex)
                }
            }
        }
        
        dismissMessageSilently()
    }
    
    @objc private func overlayTapped() {
        dismissMessage()
    }
    
    /// Handle subscribe action using bridge pattern
    private func handleSubscribeAction() {
        guard let viewController = currentViewController else { return }
        
        Task {
            let success = await subscriptionHandler.requestSubscription(viewController: viewController)
            InAppLogger.shared.info("Subscribe action result: \(success)")
            
            DispatchQueue.main.async {
                self.dismissMessageSilently()
            }
        }
    }
    
    // MARK: - Dismiss Methods
    
    /// Internal dismissal method with event control
    private func dismissMessageInternal(sendCloseEvent: Bool) {
        guard !isDismissing, let messageView = currentMessageView, let message = currentMessage else { return }
        
        isDismissing = true
        
        if sendCloseEvent {
            onMessageEvent("inapp.close", message, nil)
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
