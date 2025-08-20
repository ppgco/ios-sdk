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
        if let image = message.image, !image.url.isEmpty {
            let imageSection = createImageSection(for: image)
            mainStack.addArrangedSubview(imageSection)
            
            // Set image width to 40% of container
            imageSection.widthAnchor.constraint(equalTo: mainStack.widthAnchor, multiplier: 0.4).isActive = true
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
        
        // Apply paddingBody from layout
        let paddingBody = UIStyleParser.parsePaddingString(message.layout.paddingBody)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: paddingBody.top),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: paddingBody.left),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -paddingBody.right),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -paddingBody.bottom)
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
    
    /// Setup constraints for desktop modal
    public static func setupConstraints(_ messageView: UIView, in viewController: UIViewController) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        let margin: CGFloat = 20
        
        let screenWidth = viewController.view.frame.width
        let screenHeight = viewController.view.frame.height
        let maxWidth: CGFloat = 520
        let preferredWidth = min(maxWidth, screenWidth - 40)
        
        NSLayoutConstraint.activate([
            // Center horizontally and vertically
            messageView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            
            // Width constraints
            messageView.widthAnchor.constraint(equalToConstant: preferredWidth),
            messageView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: margin),
            messageView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -margin),
            
            // Height constraints - content-driven but with limits
            messageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            messageView.heightAnchor.constraint(lessThanOrEqualToConstant: screenHeight * 0.8)
        ])
        
        InAppLogger.shared.info("↔️ Template 3 Horizontal Modal: \(preferredWidth)px wide, image left + content right")
    }
}
