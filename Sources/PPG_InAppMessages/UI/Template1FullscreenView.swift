// Template1FullscreenView.swift
// Fullscreen template (TOP/BOTTOM placement) - Image 50%, Content 50%

import Foundation
import UIKit

/// Template 1: Fullscreen layout with image taking 50% of screen height
public class Template1FullscreenView {
    
    /// Create template view for fullscreen
    public static func createView(for message: InAppMessage) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor(hex: message.style.backgroundColor)
        
        // Apply border styling
        if message.style.border {
            containerView.layer.borderWidth = CGFloat(message.style.borderWidth)
            containerView.layer.borderColor = UIColor(hex: message.style.borderColor).cgColor
        }
        
        // Apply border radius
        containerView.layer.cornerRadius = UIStyleParser.parseFloat(message.style.borderRadius)
        
        // Apply drop shadow if enabled
        if message.style.dropShadow {
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
            containerView.layer.shadowOpacity = 0.3
            containerView.layer.shadowRadius = 8
        }
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create main stack for 50/50 split
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Top section - Image (50% of screen)
        let imageSection = createImageSection(for: message)
        mainStack.addArrangedSubview(imageSection)
        
        // Bottom section - Content (50% of screen)
        let contentSection = createContentSection(for: message)
        mainStack.addArrangedSubview(contentSection)
        
        containerView.addSubview(mainStack)
        
        // Apply padding to main stack
        let padding = UIStyleParser.parsePaddingString(message.layout.padding)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: padding.top),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            mainStack.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -padding.bottom)
        ])
        
        return containerView
    }
    
    /// Create image section (top 50%)
    private static func createImageSection(for message: InAppMessage) -> UIView {
        let sectionView = UIView()
        
        if let image = message.image, !image.url.isEmpty {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Load image
            SharedUIComponents.loadImageAsync(from: image.url, into: imageView)
            
            sectionView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: sectionView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor)
            ])
        } else {
            // If no image, use background color
            sectionView.backgroundColor = UIColor(hex: message.style.backgroundColor)
        }
        
        return sectionView
    }
    
    /// Create content section with title, description and actions
    private static func createContentSection(for message: InAppMessage) -> UIView {
        let sectionView = UIView()
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Apply paddingBody to content section first
        let paddingBody = UIStyleParser.parsePaddingString(message.layout.paddingBody)
        
        // Check if content should be centered (when paddingBody is minimal - spaceBetweenImageAndBody doesn't affect this)
        let shouldCenterContent = paddingBody.top <= 5 && paddingBody.bottom <= 5
        
        // Create vertical stack for content with proper spacing from layout
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = CGFloat(message.layout.spaceBetweenTitleAndDescription)
        contentStack.alignment = .fill  // Changed to .fill for full width buttons
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Check if we should force full width for text
        let forceFullWidth = shouldCenterContent
        
        // Add title with font family
        if let title = message.title {
            let titleLabel = SharedUIComponents.createTitleLabel(for: title, fontFamily: message.style.fontFamily, forceFullWidth: forceFullWidth)
            contentStack.addArrangedSubview(titleLabel)
        }
        
        // Add description with font family
        if let description = message.description {
            let descriptionLabel = SharedUIComponents.createDescriptionLabel(for: description, fontFamily: message.style.fontFamily, forceFullWidth: forceFullWidth)
            contentStack.addArrangedSubview(descriptionLabel)
        }
        
        // Add spacing before actions if specified
        if !message.actions.isEmpty && message.layout.spaceBetweenContentAndActions > 0 {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: CGFloat(message.layout.spaceBetweenContentAndActions)).isActive = true
            contentStack.addArrangedSubview(spacer)
        }
        
        // Add actions at bottom with full width
        if !message.actions.isEmpty {
            let actionsView = SharedUIComponents.createActionsView(for: message, fillWidth: true)
            contentStack.addArrangedSubview(actionsView)
        }
        
        sectionView.addSubview(contentStack)
        
        if shouldCenterContent {
            // Center content in the section with full width when paddingBody is 0
            NSLayoutConstraint.activate([
                contentStack.centerXAnchor.constraint(equalTo: sectionView.centerXAnchor),
                contentStack.centerYAnchor.constraint(equalTo: sectionView.centerYAnchor),
                contentStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: paddingBody.left),
                contentStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -paddingBody.right)
            ])
        } else {
            // Use paddingBody constraints
            NSLayoutConstraint.activate([
                contentStack.topAnchor.constraint(equalTo: sectionView.topAnchor, constant: paddingBody.top),
                contentStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: paddingBody.left),
                contentStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -paddingBody.right),
                contentStack.bottomAnchor.constraint(lessThanOrEqualTo: sectionView.bottomAnchor, constant: -paddingBody.bottom)
            ])
        }
        
        return sectionView
    }
    
    /// Setup constraints for fullscreen template
    public static func setupConstraints(_ messageView: UIView, in viewController: UIViewController) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            messageView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            messageView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            messageView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        InAppLogger.shared.info("📱 Template 1 Fullscreen: Image 50% + Content 50%")
    }
}

