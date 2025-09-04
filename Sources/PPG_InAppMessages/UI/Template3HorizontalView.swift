// Template3HorizontalView.swift
// Horizontal template - Image left side, content right side

import Foundation
import UIKit

/// Template 3: Horizontal layout with image on left, content on right
public class Template3HorizontalView {
    
    /// Create horizontal template view
    public static func createView(for message: InAppMessage) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor(hex: message.style.backgroundColor)
        
        // Apply border radius (always, regardless of border setting)
        containerView.layer.cornerRadius = UIStyleParser.parseFloat(message.style.borderRadius)
        
        // Apply border styling
        if message.style.border {
            containerView.layer.borderWidth = CGFloat(message.style.borderWidth)
            containerView.layer.borderColor = UIColor(hex: message.style.borderColor).cgColor
        }
        containerView.clipsToBounds = true
        
        // Add drop shadow if enabled
        if message.style.dropShadow {
            addDropShadow(to: containerView)
        }
        
        // Main horizontal stack
        let mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)
        mainStack.alignment = .fill
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add image section (left side - 40% width)
        if let imageData = message.image, !imageData.url.isEmpty, !imageData.hideOnMobile {
            let imageView = SharedUIComponents.createImageView(for: imageData.url)
            mainStack.addArrangedSubview(imageView)
            
            // Set image width to 40% of container
            imageView.widthAnchor.constraint(equalTo: mainStack.widthAnchor, multiplier: 0.4).isActive = true
        }
        
        // Add content section (right side - 60% width)
        let contentSection = createContentSection(for: message)
        mainStack.addArrangedSubview(contentSection)
        
        containerView.addSubview(mainStack)
        
        // Apply padding
        let padding = UIStyleParser.parsePadding(message.layout.paddingBody)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom)
        ])
        
        return containerView
    }
    
    /// Create image section (left side)
    private static func createImageSection(for image: MessageImage) -> UIView {
        let imageContainer = UIView()
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Load image
        SharedUIComponents.loadImageAsync(from: image.url, into: imageView)
        
        imageContainer.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            // Minimum height for image
            imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        
        return imageContainer
    }
    
    /// Create content section (right side)
    private static func createContentSection(for message: InAppMessage) -> UIView {
        let contentView = UIView()
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = CGFloat(message.layout.spaceBetweenTitleAndDescription)
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add title with font family
        if let title = message.title {
            let titleLabel = SharedUIComponents.createTitleLabel(for: title, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            contentStack.addArrangedSubview(titleLabel)
        }
        
        // Add description with font family
        if let description = message.description {
            let descriptionLabel = SharedUIComponents.createDescriptionLabel(for: description, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
            contentStack.addArrangedSubview(descriptionLabel)
        }
        
        // Add spacer to push actions to bottom
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(spacer)
        
        // Add actions at bottom
        if !message.actions.isEmpty {
            let spacerBeforeActions = UIView()
            spacerBeforeActions.heightAnchor.constraint(equalToConstant: CGFloat(message.layout.spaceBetweenContentAndActions)).isActive = true
            contentStack.addArrangedSubview(spacerBeforeActions)
            
            let actionsView = SharedUIComponents.createActionsView(for: message)
            contentStack.addArrangedSubview(actionsView)
        }
        
        contentView.addSubview(contentStack)
        
        // Apply padding from layout
        let paddingValues = UIStyleParser.parsePadding(message.layout.padding ?? "20px")
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: paddingValues.top),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: paddingValues.left),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -paddingValues.right),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -paddingValues.bottom)
        ])
        
        return contentView
    }
    
    /// Add drop shadow to container
    private static func addDropShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.15
        view.layer.masksToBounds = false
    }
    
    /// Setup constraints for horizontal modal with placement support
    public static func setupConstraints(_ messageView: UIView, in viewController: UIViewController, placement: String? = nil, marginString: String? = nil) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        let margin = UIStyleParser.parseFloat(marginString ?? "20px")
        
        let screenWidth = viewController.view.frame.width
        let screenHeight = viewController.view.frame.height
        let maxWidth: CGFloat = 520
        let preferredWidth = min(maxWidth, screenWidth - 40)
        
        // Determine position based on placement
        let placementUpper = (placement ?? "CENTER").uppercased()
        let isTop = placementUpper.hasPrefix("TOP")
        let isBottom = placementUpper.hasPrefix("BOTTOM")
        // CENTER, LEFT, RIGHT all go to center
        
        var constraints: [NSLayoutConstraint] = [
            // Always center horizontally
            messageView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            
            // Width constraints
            messageView.widthAnchor.constraint(equalToConstant: preferredWidth),
            messageView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: margin),
            messageView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -margin),
            
            // Height constraints - content-driven but with limits
            messageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            messageView.heightAnchor.constraint(lessThanOrEqualToConstant: screenHeight * 0.8)
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
        
        let positionDesc = isTop ? "top" : (isBottom ? "bottom" : "centered")
        InAppLogger.shared.info("↔️ Template 3 Horizontal Modal: \(preferredWidth)px wide, \(positionDesc), image left + content right")
    }
}
