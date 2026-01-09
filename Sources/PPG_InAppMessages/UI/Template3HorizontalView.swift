import Foundation
import UIKit

/// Template 3: Horizontal layout with image on left, content on right
internal class Template3HorizontalView {
    
    /// Create horizontal template view
    static func createView(for message: InAppMessage) -> UIView {
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
        
        // Main horizontal stack - 68px image / flexible content / 35% actions
        let mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)  // Only between image and text
        mainStack.alignment = .top  // Align to top instead of fill for better text layout
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Create intermediate container for text and actions with spaceBetweenContentAndActions
        let contentActionsStack = UIStackView()
        contentActionsStack.axis = .horizontal
        contentActionsStack.spacing = CGFloat(message.layout.spaceBetweenContentAndActions)  // Between text and actions
        contentActionsStack.alignment = .center
        contentActionsStack.distribution = .fill
        contentActionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Check if image should be shown
        let shouldShowImage = message.image != nil && !message.image!.url.isEmpty && !message.image!.hideOnMobile
        
        if shouldShowImage {
            // Left section - Image
            // Use paddingBody to align image with text content (top and bottom)
            let paddingBody = UIStyleParser.parsePadding(message.layout.paddingBody)
            let imageSection = createImageSection(for: message.image!, topPadding: paddingBody.top, bottomPadding: paddingBody.bottom)
            mainStack.addArrangedSubview(imageSection)
            
            // Set image width: 60px image
            let imageWidth: CGFloat = 60
            imageSection.widthAnchor.constraint(equalToConstant: imageWidth).isActive = true
        }
        
        // Middle section - Title and Description 
        // Pass hasActions flag and layoutPaddingRight to determine right padding
        let hasActions = !message.actions.isEmpty
        let layoutPadding = UIStyleParser.parsePadding(message.layout.padding)
        let textSection = createTextSection(for: message, hasActions: hasActions, layoutPaddingRight: layoutPadding.right)
        contentActionsStack.addArrangedSubview(textSection)
        
        // Set text section to be flexible
        textSection.setContentCompressionResistancePriority(UILayoutPriority(750), for: .horizontal)
        textSection.setContentCompressionResistancePriority(.required, for: .vertical)
        textSection.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Right section - Actions (35% width)
        var actionsSection: UIView? = nil
        if !message.actions.isEmpty {
            // Pass layout.padding so closeIcon padding can account for it
            let layoutPadding = UIStyleParser.parsePadding(message.layout.padding)
            actionsSection = createActionsSection(for: message, layoutPaddingRight: layoutPadding.right)
            contentActionsStack.addArrangedSubview(actionsSection!)
            
            // Allow actions section to expand vertically as needed
            actionsSection!.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            actionsSection!.setContentHuggingPriority(.defaultLow, for: .vertical)
        }
        
        // Add contentActionsStack to mainStack
        mainStack.addArrangedSubview(contentActionsStack)
        
        containerView.addSubview(mainStack)
        
        // Apply main container padding (layout.padding) - respect 0px values
        // Add borderWidth to padding when border is enabled to prevent content overlap
        var padding = UIStyleParser.parsePadding(message.layout.padding)
        if message.style.border {
            let borderWidth = CGFloat(message.style.borderWidth)
            padding = UIEdgeInsets(
                top: padding.top + borderWidth,
                left: padding.left + borderWidth,
                bottom: padding.bottom + borderWidth,
                right: padding.right + borderWidth
            )
        }
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom)
        ])
        
        // Set actions section width after view hierarchy is established
        if let actionsSection = actionsSection {
            let actionsWidthConstraint = actionsSection.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.35)
            actionsWidthConstraint.priority = UILayoutPriority(999)
            actionsWidthConstraint.isActive = true
        }
        
        return containerView
    }
    
    /// Create image section (left side, small square aligned with text content)
    private static func createImageSection(for image: MessageImage, topPadding: CGFloat = 0, bottomPadding: CGFloat = 0) -> UIView {
        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Load image
        SharedUIComponents.loadImageAsync(from: image.url, into: imageView)
        
        imageContainer.addSubview(imageView)
        
        // Image as small square (60x60) positioned with paddingBody offsets
        // Top constraint positions image, bottom constraint ensures minimum container height
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: topPadding),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: imageContainer.bottomAnchor, constant: -bottomPadding)
        ])
        
        return imageContainer
    }
    
    /// Create text section (middle - 40% width, title 50% + description 50%)
    /// - Parameter hasActions: If false, text section is at right edge and needs paddingBody.right
    /// - Parameter layoutPaddingRight: Right padding from layout.padding (already applied to mainStack)
    private static func createTextSection(for message: InAppMessage, hasActions: Bool, layoutPaddingRight: CGFloat) -> UIView {
        let textView = UIView()
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.alignment = .fill
        textStack.distribution = .fill  // Allow flexible height based on content
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add title with font family (flexible height)
        if let title = message.title {
            let titleLabel = SharedUIComponents.createTitleLabel(for: title, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
            
            textStack.addArrangedSubview(titleLabel)
            
            // Apply custom spacing after title (only if description exists)
            if message.description != nil {
                textStack.setCustomSpacing(CGFloat(message.layout.spaceBetweenTitleAndDescription), after: titleLabel)
            }
        }
        
        // Add description with font family (flexible height)
        if let description = message.description {
            let descriptionLabel = SharedUIComponents.createDescriptionLabel(for: description, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            descriptionLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
            
            textStack.addArrangedSubview(descriptionLabel)
        }
        
        textView.addSubview(textStack)
        
        // Apply paddingBody to the text container (title + description content)
        let paddingBody = UIStyleParser.parsePadding(message.layout.paddingBody)
        
        // Right padding logic:
        // - If hasActions: no right padding (spacing controlled by spaceBetweenContentAndActions)
        // - If no actions: apply paddingBody.right + closeIcon padding (text is at right edge)
        var rightPadding: CGFloat = 0
        if !hasActions {
            rightPadding = paddingBody.right
            // Add closeIcon padding only if existing padding is not enough
            if message.style.closeIcon {
                let closeIconSize = CGFloat(message.style.closeIconWidth)
                let neededPadding = closeIconSize + 4
                let existingPadding = layoutPaddingRight + paddingBody.right
                if existingPadding < neededPadding {
                    rightPadding += (neededPadding - existingPadding)
                }
            }
        }
        
        // Set proper priorities to ensure text content is never cut off
        textStack.setContentCompressionResistancePriority(.required, for: .vertical)
        textStack.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: textView.topAnchor, constant: paddingBody.top),
            textStack.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: paddingBody.left),
            textStack.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -rightPadding),
            textStack.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -paddingBody.bottom)
        ])
        
        return textView
    }
    
    /// Create actions section (right side - 45% width, buttons stacked vertically and centered)
    /// - Parameter layoutPaddingRight: Right padding from layout.padding (already applied to mainStack)
    private static func createActionsSection(for message: InAppMessage, layoutPaddingRight: CGFloat) -> UIView {
        let actionsView = UIView()
        
        let actionsStack = UIStackView()
        actionsStack.axis = .vertical  // Buttons stacked vertically
        actionsStack.spacing = 8  // Space between buttons
        actionsStack.alignment = .fill  // Fill width for equal button widths
        actionsStack.distribution = .fill  // Simple fill - no spacers needed as parent centers us
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Collect buttons to ensure equal width
        var buttons: [UIButton] = []
        
        // Add action buttons
        for (index, action) in message.actions.enumerated() {
            if action.enabled {
                let button = SharedUIComponents.createActionButton(for: action, actionIndex: index, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
                actionsStack.addArrangedSubview(button)
                buttons.append(button)
            }
        }
        
        // Ensure all buttons have the same width
        if buttons.count > 1 {
            for i in 1..<buttons.count {
                buttons[i].widthAnchor.constraint(equalTo: buttons[0].widthAnchor).isActive = true
            }
        }
        
        actionsView.addSubview(actionsStack)
        
        // Apply paddingBody to the actions container
        var paddingBody = UIStyleParser.parsePadding(message.layout.paddingBody)
        
        // Add dynamic right padding based on close icon size to prevent overlap
        // Account for layout.padding.right which is already applied to mainStack
        if message.style.closeIcon {
            let closeIconSize = CGFloat(message.style.closeIconWidth)
            let neededPadding = closeIconSize + 4
            let existingPadding = layoutPaddingRight + paddingBody.right
            if existingPadding < neededPadding {
                paddingBody.right += (neededPadding - existingPadding)
            }
        }
        
        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: actionsView.topAnchor, constant: paddingBody.top),
            actionsStack.leadingAnchor.constraint(equalTo: actionsView.leadingAnchor, constant: 0),
            actionsStack.trailingAnchor.constraint(equalTo: actionsView.trailingAnchor, constant: -paddingBody.right),
            actionsStack.bottomAnchor.constraint(equalTo: actionsView.bottomAnchor, constant: -paddingBody.bottom)
        ])
        
        return actionsView
    }
    
    
    /// Setup constraints for horizontal modal with full-width layout for Review template
    static func setupConstraints(_ messageView: UIView, in viewController: UIViewController, placement: String? = nil, marginString: String? = nil) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        // Template3 ignores margin completely - always full-width for Review template
        
        let screenWidth = viewController.view.frame.width
        let screenHeight = viewController.view.frame.height
        
        // Determine position based on placement
        let placementUpper = (placement ?? "CENTER").uppercased()
        let isTop = placementUpper.hasPrefix("TOP")
        let isBottom = placementUpper.hasPrefix("BOTTOM")
        
        var constraints: [NSLayoutConstraint] = [
            // Full-width constraints - always stretch edge to edge, ignore margin completely
            messageView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            messageView.widthAnchor.constraint(equalToConstant: screenWidth),
            
            // Height constraints - content-driven, expand as needed for long text
            messageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),  // Minimum height
            messageView.heightAnchor.constraint(lessThanOrEqualToConstant: screenHeight * 0.9)  // Allow more height for long text
        ]
        
        // Add vertical positioning based on placement (no margin used)
        if isTop {
            constraints.append(messageView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor))
        } else if isBottom {
            constraints.append(messageView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor))
        } else {
            // CENTER (default)
            constraints.append(messageView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor))
        }
        
        NSLayoutConstraint.activate(constraints)
    }
}
