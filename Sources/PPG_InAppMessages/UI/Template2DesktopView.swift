// Template2DesktopView.swift
// Desktop modal template (CENTER placement) - Centered modal with image and content

import Foundation
import UIKit

/// Template 2: Desktop modal layout - centered card with image and content
public class Template2DesktopView {
    
    /// Create desktop modal template view
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
        
        // Main content stack
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add image if present and not hidden on mobile
        if let imageData = message.image, !imageData.url.isEmpty, !imageData.hideOnMobile {
            let imageView = SharedUIComponents.createImageView(for: imageData.url)
            imageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
            mainStack.addArrangedSubview(imageView)
        }
        
        // Add content section
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
    
    /// Create image section for desktop modal
    private static func createImageSection(for image: MessageImage) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // Load image
        SharedUIComponents.loadImageAsync(from: image.url, into: imageView)
        
        // Set aspect ratio constraint (16:9 or similar)
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 9.0/16.0).isActive = true
        
        return imageView
    }
    
    /// Create content section
    private static func createContentSection(for message: InAppMessage) -> UIView {
        let contentView = UIView()
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = CGFloat(message.layout.spaceBetweenTitleAndDescription)
        contentStack.alignment = .fill
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
        
        // Add spacing before actions
        if !message.actions.isEmpty {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: CGFloat(message.layout.spaceBetweenContentAndActions)).isActive = true
            contentStack.addArrangedSubview(spacer)
            
            // Add actions
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
    
    /// Setup constraints for desktop modal with placement support
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
            
            // Height constraints - let content determine but set limits
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
        InAppLogger.shared.info("🖥️ Template 2 Desktop Modal: \(preferredWidth)px wide, \(positionDesc)")
    }
}
