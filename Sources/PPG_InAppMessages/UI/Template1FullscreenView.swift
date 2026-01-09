import Foundation
import UIKit

/// Template 1: Fullscreen layout with image taking 50% of screen height
internal class Template1FullscreenView {
    
    /// Create template view for fullscreen
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
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Main container - vertical stack: image (50%) + content (50%)
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = CGFloat(message.layout.spaceBetweenImageAndBody)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Check if image should be shown
        let shouldShowImage = message.image != nil && !message.image!.url.isEmpty && !message.image!.hideOnMobile
        
        if shouldShowImage {
            // 50/50 split when image is visible
            mainStack.distribution = .fillEqually
            
            // Top section - Image (50% of screen)
            let imageSection = createImageSection(for: message)
            mainStack.addArrangedSubview(imageSection)
            
            // Bottom section - Content (50% of screen)
            let contentSection = createContentSection(for: message)
            mainStack.addArrangedSubview(contentSection)
        } else {
            // Full height for content when image is hidden
            mainStack.distribution = .fill
            
            // Only content section - takes full height
            let contentSection = createContentSection(for: message)
            mainStack.addArrangedSubview(contentSection)
        }
        
        containerView.addSubview(mainStack)
        
        // Apply padding to main stack, accounting for border width
        let padding = UIStyleParser.parsePaddingString(message.layout.padding)
        let borderWidth = message.style.border ? CGFloat(message.style.borderWidth) : 0
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top + borderWidth),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left + borderWidth),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -(padding.right + borderWidth)),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -(padding.bottom + borderWidth))
        ])
        
        return containerView
    }
    
    /// Create image section (top 50%)
    private static func createImageSection(for message: InAppMessage) -> UIView {
        let sectionView = UIView()
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        
        if let image = message.image, !image.url.isEmpty {
            if let imageData = message.image, !imageData.hideOnMobile {
                let imageUIView = SharedUIComponents.createImageView(for: imageData.url)
                imageUIView.translatesAutoresizingMaskIntoConstraints = false
                imageUIView.backgroundColor = UIColor(hex: message.style.backgroundColor) // Match message background
                sectionView.addSubview(imageUIView)
                
                NSLayoutConstraint.activate([
                    imageUIView.topAnchor.constraint(equalTo: sectionView.topAnchor),
                    imageUIView.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
                    imageUIView.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
                    imageUIView.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor)
                ])
            } else {
                // If image hidden on mobile, use background color
                sectionView.backgroundColor = UIColor(hex: message.style.backgroundColor)
            }
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
        sectionView.backgroundColor = UIColor(hex: message.style.backgroundColor) // Match message background
        
        // Apply paddingBody to content section first
        let paddingBody = UIStyleParser.parsePaddingString(message.layout.paddingBody)
        
        // Check if content should be centered (only when ALL paddingBody values are 0 or very close to 0)
        let shouldCenterContent = paddingBody.top <= 1 && paddingBody.bottom <= 1 && 
                                 paddingBody.left <= 1 && paddingBody.right <= 1
        
        // Create vertical stack for content with proper spacing from layout
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill  // Changed to .fill for full width buttons
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        let forceFullWidth = shouldCenterContent
        
        // Add flexible top spacer to center content vertically
        let topSpacer = createFlexibleSpacer()
        contentStack.addArrangedSubview(topSpacer)
        
        // Add title with font family
        if let title = message.title {
            let titleLabel = SharedUIComponents.createTitleLabel(for: title, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl, forceFullWidth: forceFullWidth)
            contentStack.addArrangedSubview(titleLabel)
            
            // Apply custom spacing after title (only if description exists)
            if message.description != nil {
                let spacing = CGFloat(message.layout.spaceBetweenTitleAndDescription)
                contentStack.setCustomSpacing(spacing, after: titleLabel)
            }
        }
        
        // Add description with font family
        if let description = message.description {
            let descriptionLabel = SharedUIComponents.createDescriptionLabel(for: description, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl, forceFullWidth: forceFullWidth)
            contentStack.addArrangedSubview(descriptionLabel)
        }
        
        // Add fixed spacing before actions if specified
        if !message.actions.isEmpty && message.layout.spaceBetweenContentAndActions > 0 {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: CGFloat(message.layout.spaceBetweenContentAndActions)).isActive = true
            contentStack.addArrangedSubview(spacer)
        }
        
        // Add actions if present
        if !message.actions.isEmpty {
            let actionsView = SharedUIComponents.createActionsView(for: message, fillWidth: true)
            contentStack.addArrangedSubview(actionsView)
        }
        
        // Add bottom spacer to center all content vertically
        let bottomSpacer = createFlexibleSpacer()
        contentStack.addArrangedSubview(bottomSpacer)
        
        // Equal height with top spacer for perfect centering
        bottomSpacer.heightAnchor.constraint(equalTo: topSpacer.heightAnchor).isActive = true
        
        sectionView.addSubview(contentStack)
        
        if shouldCenterContent {
            // When padding is zero, stretch full width and center vertically
            let paddingValues = UIStyleParser.parsePadding(message.layout.padding)
            
            NSLayoutConstraint.activate([
                contentStack.centerXAnchor.constraint(equalTo: sectionView.centerXAnchor),
                contentStack.centerYAnchor.constraint(equalTo: sectionView.centerYAnchor),
                contentStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: paddingValues.left),
                contentStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -paddingValues.right)
            ])
        } else {
            // When paddingBody has values, apply all four sides padding (no centering)
            NSLayoutConstraint.activate([
                contentStack.topAnchor.constraint(equalTo: sectionView.topAnchor, constant: paddingBody.top),
                contentStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: paddingBody.left),
                contentStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -paddingBody.right),
                contentStack.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor, constant: -paddingBody.bottom)
            ])
        }
        
        return sectionView
    }
    
    /// Create flexible spacer for vertical centering
    private static func createFlexibleSpacer() -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return spacer
    }
    
    /// Setup constraints for fullscreen template
    static func setupConstraints(_ messageView: UIView, in viewController: UIViewController) {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            messageView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            messageView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            messageView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}

