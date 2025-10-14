import Foundation
import UIKit

/// Template 2: Desktop modal layout - centered card with image and content
public class Template2DesktopView {
    
    /// Create desktop modal template view
    public static func createView(for message: InAppMessage) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor(hex: message.style.backgroundColor)
        
        // Apply border radius with CACornerMask support for individual corners (iOS 11+)
        UIStyleParser.applyBorderRadius(to: containerView, radiusString: message.style.borderRadius)
        
        // Apply border styling
        if message.style.border {
            containerView.layer.borderWidth = CGFloat(message.style.borderWidth)
            containerView.layer.borderColor = UIColor(hex: message.style.borderColor).cgColor
        }
        containerView.clipsToBounds = true
        
        // Main horizontal stack - image 30% left + content 70% right
        let mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)
        mainStack.alignment = .top
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.clipsToBounds = true
        
        // Check if image should be shown
        let shouldShowImage = message.image != nil && !message.image!.url.isEmpty && !message.image!.hideOnMobile
        
        if shouldShowImage {
            // Left section - Image (fixed 72x72px)
            let imageSection = createImageSection(for: message.image!)
            mainStack.addArrangedSubview(imageSection)
        }
        
        // Right section - Content (70% width when image present, 100% when not)
        let contentSection = createContentSection(for: message)
        mainStack.addArrangedSubview(contentSection)
        
        containerView.addSubview(mainStack)
        
        // Apply main container padding (layout.padding)
        let padding = UIStyleParser.parsePadding(message.layout.padding)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom)
        ])
        
        return containerView
    }
    
    /// Create image section for desktop modal (fixed 72x72px square)
    private static func createImageSection(for image: MessageImage) -> UIView {
        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Load image
        SharedUIComponents.loadImageAsync(from: image.url, into: imageView)
        
        imageContainer.addSubview(imageView)
        
        // Fixed 72x72px size as per CSS specification
        NSLayoutConstraint.activate([
            imageContainer.widthAnchor.constraint(equalToConstant: 72),
            imageContainer.heightAnchor.constraint(equalToConstant: 72),
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor)
        ])
        
        return imageContainer
    }
    
    /// Create content section
    private static func createContentSection(for message: InAppMessage) -> UIView {
        let contentView = UIView()
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.clipsToBounds = true
        
        // Add title with font family
        if let title = message.title {
            let titleLabel = SharedUIComponents.createTitleLabel(for: title, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            contentStack.addArrangedSubview(titleLabel)
            
            // Apply custom spacing after title (only if description exists)
            if message.description != nil {
                contentStack.setCustomSpacing(CGFloat(message.layout.spaceBetweenTitleAndDescription), after: titleLabel)
            }
        }
        
        // Add description with font family
        if let description = message.description {
            let descriptionLabel = SharedUIComponents.createDescriptionLabel(for: description, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            contentStack.addArrangedSubview(descriptionLabel)
        }
        
        // Add spacing before actions
        if !message.actions.isEmpty {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: CGFloat(message.layout.spaceBetweenContentAndActions)).isActive = true
            contentStack.addArrangedSubview(spacer)
            
            // Add actions with reversed order for Template 2
            let actionsView = createReversedActionsView(for: message)
            contentStack.addArrangedSubview(actionsView)
        }
        
        contentView.addSubview(contentStack)
        
        // No padding here - it's already applied at the main stack level
        // Apply paddingBody to the content container (title + description + actions)
        let paddingBody = UIStyleParser.parsePadding(message.layout.paddingBody)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: paddingBody.top),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: paddingBody.left),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -paddingBody.right),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -paddingBody.bottom)
        ])
        
        return contentView
    }
    
    /// Create actions view with reversed order (Template 2 specific)
    private static func createReversedActionsView(for message: InAppMessage) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create buttons in reverse order
        var buttons: [UIButton] = []
        for (originalIndex, action) in message.actions.enumerated().reversed() {
            if action.enabled {
                // Use original index even though buttons are displayed in reverse order
                let button = SharedUIComponents.createActionButton(for: action, actionIndex: originalIndex, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
                button.translatesAutoresizingMaskIntoConstraints = false
                
                // Force button to calculate its proper size
                button.sizeToFit()
                button.invalidateIntrinsicContentSize()
                button.setNeedsLayout()
                button.layoutIfNeeded()
                
                // Force titleLabel to update
                button.titleLabel?.sizeToFit()
                button.titleLabel?.invalidateIntrinsicContentSize()
                
                containerView.addSubview(button)
                buttons.append(button)
            }
        }
        
        // Manual constraints WITH equal widths but allowing different heights
        // No padding - buttons extend to edges and get clipped by container corner radius
        if buttons.count == 2 {
            let button1 = buttons[0]
            let button2 = buttons[1]
            
            NSLayoutConstraint.activate([
                // Vertical positioning - top aligned
                button1.topAnchor.constraint(equalTo: containerView.topAnchor),
                button2.topAnchor.constraint(equalTo: containerView.topAnchor),
                
                // Horizontal positioning with 8px spacing between buttons
                button1.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button2.leadingAnchor.constraint(equalTo: button1.trailingAnchor, constant: 8),
                button2.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                
                // RESTORED equal width constraint - buttons should have same width
                button1.widthAnchor.constraint(equalTo: button2.widthAnchor),
                
                // Container height matches tallest button
                containerView.bottomAnchor.constraint(greaterThanOrEqualTo: button1.bottomAnchor),
                containerView.bottomAnchor.constraint(greaterThanOrEqualTo: button2.bottomAnchor)
            ])
        } else if buttons.count == 1 {
            let button = buttons[0]
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: containerView.topAnchor),
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return containerView
    }
    
    /// Setup constraints for desktop modal with placement support
    public static func setupConstraints(_ messageView: UIView, in viewController: UIViewController, placement: String? = nil, marginString: String? = nil) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        // Template2 uses fixed margin, ignores backend layout.margin
        let margin: CGFloat = 15
        
        let screenWidth = viewController.view.frame.width
        let screenHeight = viewController.view.frame.height
        let maxWidth: CGFloat = 520
        let preferredWidth = min(maxWidth, screenWidth - 40)
        
        // Determine position based on placement (Template2 always centered horizontally)
        let placementUpper = (placement ?? "CENTER").uppercased()
        let isTop = placementUpper.hasPrefix("TOP")
        let isBottom = placementUpper.hasPrefix("BOTTOM")
        // Note: Template2 ignores LEFT/RIGHT - always centers horizontally
        
        var constraints: [NSLayoutConstraint] = [
            // Width constraints
            messageView.widthAnchor.constraint(equalToConstant: preferredWidth),
            messageView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: margin),
            messageView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -margin),
            
            // Height constraints - let content determine size naturally
            messageView.heightAnchor.constraint(lessThanOrEqualToConstant: screenHeight * 0.8),
            
            // Always center horizontally for Template2
            messageView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor)
        ]
        
        // Add vertical positioning based on placement
        if isTop {
            constraints.append(messageView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor, constant: margin))
        } else if isBottom {
            constraints.append(messageView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -margin))
        } else {
            // CENTER (default)
            constraints.append(messageView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor))
        }
        
        NSLayoutConstraint.activate(constraints)
    }
}
