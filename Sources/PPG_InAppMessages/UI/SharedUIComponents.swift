// SharedUIComponents.swift
// Shared UI components for all in-app message templates

import Foundation
import UIKit

/// Shared UI component factory for in-app messages
public class SharedUIComponents {
    
    // MARK: - Helper Methods
    
    
    // MARK: - Button Creation
    
    /// Create close button with style from payload
    public static func createCloseButton(style: MessageStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("✕", for: .normal)
        button.setTitleColor(UIColor(hex: style.closeIconColor), for: .normal)
        
        let iconSize = CGFloat(style.closeIconWidth)
        button.titleLabel?.font = UIFont.systemFont(ofSize: iconSize, weight: .medium)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        button.layer.cornerRadius = iconSize / 2
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Set size based on closeIconWidth
        let buttonSize = iconSize * 1.8 // Make button slightly larger than icon
        button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
        
        // CRITICAL FIX: Set tag to -1 to distinguish from action buttons (which have tag >= 0)
        button.tag = -1
        
        return button
    }
    
    /// Create action button with full styling
    public static func createActionButton(for action: InAppMessageAction, actionIndex: Int, extraHeight: CGFloat = 0, fontFamily: String? = nil, fontUrl: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(action.text, for: .normal)
        button.setTitleColor(UIColor(hex: action.textColor), for: .normal)
        button.backgroundColor = UIColor(hex: action.backgroundColor)
        button.layer.borderColor = UIColor(hex: action.borderColor).cgColor
        button.layer.borderWidth = 1
        // Apply borderRadius with CACornerMask support for individual corners (iOS 11+)
        UIStyleParser.applyBorderRadius(to: button, radiusString: action.borderRadius)
        
        // Set initial system font with 1.3x multiplier
        let weight = UIStyleParser.parseFontWeight(action.fontWeight)
        let fontSize = CGFloat(action.fontSize) * 1.3
        
        // Apply style if specified
        let styleString = action.style.lowercased() ?? "normal"
        
        if styleString == "italic" {
            let traits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
            if let descriptor = UIFont.systemFont(ofSize: fontSize, weight: weight).fontDescriptor.withSymbolicTraits(traits) {
                button.titleLabel?.font = UIFont(descriptor: descriptor, size: fontSize)
            } else {
                button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            }
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        }
        
        // Apply underline if specified
        if styleString == "underline" {
            let attributedText = NSMutableAttributedString(string: action.text)
            let range = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            // Preserve font and color for attributed text
            attributedText.addAttribute(.font, value: button.titleLabel?.font ?? UIFont.systemFont(ofSize: 16), range: range)
            attributedText.addAttribute(.foregroundColor, value: UIColor(hex: action.textColor), range: range)
            button.setAttributedTitle(attributedText, for: .normal)
        }
        
        // Load custom font synchronously if provided
        if let fontFamily = fontFamily, !fontFamily.isEmpty {
            let styleString = action.style.lowercased() ?? "normal"
            let customFont = FontManager.shared.loadFont(
                family: fontFamily,
                size: fontSize,
                weight: action.fontWeight,
                style: styleString
            )
            
            InAppLogger.shared.info("Action font loaded: \(customFont.fontName) - weight: \(action.fontWeight), style: \(styleString)")
            button.titleLabel?.font = customFont
            
            // Apply underline if needed
            if styleString == "underline" {
                let attributedText = NSMutableAttributedString(string: action.text)
                let range = NSRange(location: 0, length: attributedText.length)
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                attributedText.addAttribute(.font, value: customFont, range: range)
                attributedText.addAttribute(.foregroundColor, value: UIColor(hex: action.textColor), range: range)
                button.setAttributedTitle(attributedText, for: .normal)
            }
        }
        
        // Add padding - supports single value or 4 values (top, right, bottom, left)
        let padding = UIStyleParser.parsePadding(action.padding)
        let adjustedPadding = UIEdgeInsets(
            top: padding.top + extraHeight/2, 
            left: padding.left, 
            bottom: padding.bottom + extraHeight/2, 
            right: padding.right
        )
        button.contentEdgeInsets = adjustedPadding
        
        // Configure button for multiline text support
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .center
        
        // Ensure button expands to fit content properly
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // Force exact height calculation based on actual text content
        // Use actual font from button for accurate measurement
        let actualFont = button.titleLabel?.font ?? UIFont.systemFont(ofSize: 16)
        let maxWidth: CGFloat = 120 // Smaller width to force text wrapping for longer texts
        
        let textBounds = (action.text as NSString).boundingRect(
            with: CGSize(width: maxWidth - adjustedPadding.left - adjustedPadding.right, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: actualFont],
            context: nil
        )
        
        // Calculate exact height needed - use ceiling to avoid fractional pixels
        let exactHeight = ceil(textBounds.height + adjustedPadding.top + adjustedPadding.bottom + 16)
        
        // Use exact height constraint with high priority to avoid conflicts with UIKit's internal constraints
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: exactHeight)
        heightConstraint.priority = UILayoutPriority(999) // High priority but not required - allows UIKit to override if needed
        heightConstraint.isActive = true
        
        print("🔴 Button text: '\(action.text)' -> calculated height: \(exactHeight)");
        
        button.tag = actionIndex
        return button
    }
    
    // MARK: - Label Creation
    
    /// Create title label with font family support
    public static func createTitleLabel(for title: MessageTitle, fontFamily: String? = nil, fontUrl: String? = nil, forceFullWidth: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = title.text
        
        // Set initial system font with 1.3x multiplier
        let weight = UIStyleParser.parseFontWeight(title.fontWeight)
        let fontSize = CGFloat(title.fontSize) * 1.3
        
        // Debug font weight
        InAppLogger.shared.info("Title font weight: \(title.fontWeight) -> \(weight.rawValue) (\(weight))")
        
        // Apply style if specified
        let styleString = title.style.lowercased() ?? "normal"
        
        // Force system font with proper weight - this ensures weight is always applied
        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: weight)
        InAppLogger.shared.info("Created system font: \(baseFont.fontName) - \(baseFont.pointSize) - weight: \(weight)")
        
        if styleString == "italic" {
            let traits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                label.font = UIFont(descriptor: descriptor, size: fontSize)
            } else {
                label.font = baseFont
            }
        } else {
            label.font = baseFont
        }
        
        // Apply underline if specified
        if styleString == "underline" {
            let attributedText = NSMutableAttributedString(string: title.text)
            let range = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            // Preserve font and color for attributed text
            attributedText.addAttribute(.font, value: label.font!, range: range)
            attributedText.addAttribute(.foregroundColor, value: UIColor(hex: title.color), range: range)
            label.attributedText = attributedText
        }
        
        // Load custom font synchronously if provided
        if let fontFamily = fontFamily, !fontFamily.isEmpty {
            let styleString = title.style.lowercased() ?? "normal"
            let customFont = FontManager.shared.loadFont(
                family: fontFamily,
                size: fontSize,
                weight: title.fontWeight,
                style: styleString
            )
            
            InAppLogger.shared.info("Title font loaded: \(customFont.fontName) - weight: \(title.fontWeight), style: \(styleString)")
            label.font = customFont
            
            // Apply styles with custom font
            let alignment = title.alignment.lowercased()
            
            let attributedText = NSMutableAttributedString(string: title.text)
            let range = NSRange(location: 0, length: attributedText.length)
            
            // Apply font
            attributedText.addAttribute(.font, value: customFont, range: range)
            attributedText.addAttribute(.foregroundColor, value: UIColor(hex: title.color), range: range)
            
            // Apply underline if needed
            if styleString == "underline" {
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            
            // Apply alignment
            let paragraphStyle = NSMutableParagraphStyle()
            switch alignment {
            case "left":
                paragraphStyle.alignment = .left
            case "center":
                paragraphStyle.alignment = .center
            case "right":
                paragraphStyle.alignment = .right
            default:
                paragraphStyle.alignment = .left
            }
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            
            label.attributedText = attributedText
        } else {
            // No custom font - ensure system font weight is preserved
            InAppLogger.shared.info("Title using system font with weight: \(weight)")
        }
        
        label.textColor = UIColor(hex: title.color)
        
        // Set text alignment - special handling for justify
        let alignment = title.alignment.lowercased()
        InAppLogger.shared.info("Title alignment: '\(title.alignment)' -> '\(alignment)'")
        
        if alignment == "justify" {
            // For justified text, preserve existing attributed text if it exists (for underline, etc.)
            let attributedText: NSMutableAttributedString
            if let existingAttributedText = label.attributedText {
                // Use existing attributed text to preserve underline and other attributes
                attributedText = NSMutableAttributedString(attributedString: existingAttributedText)
            } else {
                // Create new attributed text if none exists
                attributedText = NSMutableAttributedString(string: title.text)
                attributedText.addAttribute(.font, value: label.font!, range: NSRange(location: 0, length: attributedText.length))
                attributedText.addAttribute(.foregroundColor, value: UIColor(hex: title.color), range: NSRange(location: 0, length: attributedText.length))
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .justified
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.hyphenationFactor = 1.0  // Enable hyphenation for better justification
            
            let fullRange = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            
            label.attributedText = attributedText
            label.textAlignment = .justified  // Also set the label alignment as backup
            InAppLogger.shared.info("Applied justified alignment to title with hyphenation")
        } else {
            label.textAlignment = UIStyleParser.parseTextAlignment(title.alignment)
            InAppLogger.shared.info("Applied standard alignment: \(UIStyleParser.parseTextAlignment(title.alignment))")
        }
        
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    
    /// Create description label with font family support
    public static func createDescriptionLabel(for description: MessageDescription, fontFamily: String? = nil, fontUrl: String? = nil, forceFullWidth: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = description.text
        
        // Set initial system font with 1.3x multiplier
        let weight = UIStyleParser.parseFontWeight(description.fontWeight)
        let fontSize = CGFloat(description.fontSize) * 1.3
        
        // Debug font weight
        InAppLogger.shared.info("Description font weight: \(description.fontWeight) -> \(weight.rawValue) (\(weight))")
        
        // Apply style if specified
        let styleString = description.style.lowercased() ?? "normal"
        
        // Force system font with proper weight - this ensures weight is always applied
        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: weight)
        InAppLogger.shared.info("Created system font: \(baseFont.fontName) - \(baseFont.pointSize) - weight: \(weight)")
        
        if styleString == "italic" {
            let traits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                label.font = UIFont(descriptor: descriptor, size: fontSize)
            } else {
                label.font = baseFont
            }
        } else {
            label.font = baseFont
        }
        
        // Apply underline if specified
        if styleString == "underline" {
            let attributedText = NSMutableAttributedString(string: description.text)
            let range = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            // Preserve font and color for attributed text
            attributedText.addAttribute(.font, value: label.font!, range: range)
            attributedText.addAttribute(.foregroundColor, value: UIColor(hex: description.color), range: range)
            label.attributedText = attributedText
        }
        
        // Load custom font synchronously if provided
        if let fontFamily = fontFamily, !fontFamily.isEmpty {
            let styleString = description.style.lowercased() ?? "normal"
            let customFont = FontManager.shared.loadFont(
                family: fontFamily,
                size: fontSize,
                weight: description.fontWeight,
                style: styleString
            )
            
            InAppLogger.shared.info("Description font loaded: \(customFont.fontName) - weight: \(description.fontWeight), style: \(styleString)")
            label.font = customFont
            
            // Apply styles with custom font
            let alignment = description.alignment.lowercased()
            
            let attributedText = NSMutableAttributedString(string: description.text)
            let range = NSRange(location: 0, length: attributedText.length)
            
            // Apply font
            attributedText.addAttribute(.font, value: customFont, range: range)
            attributedText.addAttribute(.foregroundColor, value: UIColor(hex: description.color), range: range)
            
            // Apply underline if needed
            if styleString == "underline" {
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            
            // Apply paragraph style for justify alignment
            if alignment == "justify" {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .justified
                paragraphStyle.lineBreakMode = .byWordWrapping
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            } else {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = UIStyleParser.parseTextAlignment(description.alignment)
                paragraphStyle.lineBreakMode = .byWordWrapping
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }
            
            label.attributedText = attributedText
        } else {
            // No custom font - ensure system font weight is preserved
            InAppLogger.shared.info("Description using system font with weight: \(weight)")
        }
        
        label.textColor = UIColor(hex: description.color)
        
        // Set text alignment - special handling for justify
        let alignment = description.alignment.lowercased()
        InAppLogger.shared.info("Description alignment: '\(description.alignment)' -> '\(alignment)'")
        
        if alignment == "justify" {
            // For justified text, preserve existing attributed text if it exists (for underline, etc.)
            let attributedText: NSMutableAttributedString
            if let existingAttributedText = label.attributedText {
                // Use existing attributed text to preserve underline and other attributes
                attributedText = NSMutableAttributedString(attributedString: existingAttributedText)
            } else {
                // Create new attributed text if none exists
                attributedText = NSMutableAttributedString(string: description.text)
                attributedText.addAttribute(.font, value: label.font!, range: NSRange(location: 0, length: attributedText.length))
                attributedText.addAttribute(.foregroundColor, value: UIColor(hex: description.color), range: NSRange(location: 0, length: attributedText.length))
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .justified
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.hyphenationFactor = 1.0  // Enable hyphenation for better justification
            
            let fullRange = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            
            label.attributedText = attributedText
            label.textAlignment = .justified  // Also set the label alignment as backup
            InAppLogger.shared.info("Applied justified alignment to description with hyphenation")
        } else {
            label.textAlignment = UIStyleParser.parseTextAlignment(description.alignment)
            InAppLogger.shared.info("Applied standard alignment: \(UIStyleParser.parseTextAlignment(description.alignment))")
        }
        
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    
    // MARK: - Image Creation
    
    /// Create image view with async loading
    public static func createImageView(for imageUrl: String, height: CGFloat = 200) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Load image asynchronously
        loadImageAsync(from: imageUrl, into: imageView)
        
        // Don't set height constraint here - let the parent handle it
        
        return imageView
    }
    
    /// Load image asynchronously
    public static func loadImageAsync(from urlString: String, into imageView: UIImageView) {
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                
                await MainActor.run {
                    imageView.image = image
                }
            } catch {
                InAppLogger.shared.error("Failed to load image: \(error)")
            }
        }
    }
    
    // MARK: - Actions Container
    
    /// Create actions stack view (vertical for Template 1, horizontal for others)
    public static func createActionsView(for message: InAppMessage, fillWidth: Bool = false) -> UIView {
        let stackView = UIStackView()
        
        // Use vertical layout for Template 1 (fullscreen) when fillWidth is true
        if fillWidth {
            stackView.axis = .vertical
            stackView.spacing = 12  // More spacing between vertical buttons
            stackView.distribution = .fill
        } else {
            stackView.axis = .horizontal
            stackView.spacing = 8
            stackView.distribution = .fillEqually
        }
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add action buttons with extra height for Template 1 (fullscreen)
        let extraHeight: CGFloat = fillWidth ? 12 : 0  // Slightly taller for Template 1
        for (index, action) in message.actions.enumerated() {
            if action.enabled {
                let button = createActionButton(for: action, actionIndex: index, extraHeight: extraHeight, fontFamily: message.style.fontFamily, fontUrl: message.style.fontUrl)
                stackView.addArrangedSubview(button)
            }
        }
        
        return stackView
    }
}

/// Style parsing utilities
public class UIStyleParser {
    
    /// Parse float value from string
    public static func parseFloat(_ value: String) -> CGFloat {
        return CGFloat(Double(value.replacingOccurrences(of: "px", with: "")) ?? 0.0)
    }
    
    /// Map font family to system font with fallback
    public static func mapToSystemFont(fontFamily: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        // First try exact font name
        if let customFont = UIFont(name: fontFamily, size: size) {
            return customFont
        }
        
        // Map common font families to iOS system fonts
        let lowercaseFamily = fontFamily.lowercased()
        
        switch lowercaseFamily {
        case "roboto", "open sans", "fira sans":
            // Sans-serif fonts - use system font
            return UIFont.systemFont(ofSize: size, weight: weight)
            
        case "montserrat", "inter", "poppins", "lato":
            // Modern sans-serif - use system font with appropriate weight
            return UIFont.systemFont(ofSize: size, weight: weight)
            
        case "playfair display":
            // Serif display font - try system serif, fallback to system
            if #available(iOS 13.0, *) {
                return UIFont(descriptor: UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor, size: size)
            } else {
                return UIFont.systemFont(ofSize: size, weight: weight)
            }
            
        case "arial":
            // Try Arial, fallback to system
            return UIFont(name: "Arial", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
            
        case "georgia":
            // Try Georgia, fallback to system
            return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
            
        default:
            // Unknown font - use system font
            InAppLogger.shared.info("Font '\(fontFamily)' mapped to system font")
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
    
    /// Parse padding string to UIEdgeInsets - supports both single values and CSS-style multi-values
    public static func parsePadding(_ paddingString: String) -> UIEdgeInsets {
        // Use the more advanced parser that handles 1, 2, and 4 values
        return parsePaddingString(paddingString)
    }
    
    /// Parse complex padding string like "48px 24px 48px 24px" to UIEdgeInsets
    public static func parsePaddingString(_ paddingString: String) -> UIEdgeInsets {
        let components = paddingString.split(separator: " ").map { String($0) }
        
        switch components.count {
        case 1:
            // Single value: all sides
            let value = parseFloat(components[0])
            return UIEdgeInsets(top: value, left: value, bottom: value, right: value)
        case 2:
            // Two values: top/bottom, left/right
            let vertical = parseFloat(components[0])
            let horizontal = parseFloat(components[1])
            return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        case 4:
            // Four values: top, right, bottom, left
            let top = parseFloat(components[0])
            let right = parseFloat(components[1])
            let bottom = parseFloat(components[2])
            let left = parseFloat(components[3])
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        default:
            return UIEdgeInsets.zero
        }
    }
    
    /// Parse border radius string - supports CSS-style values (1, 2, or 4 values)
    public static func parseBorderRadius(_ radiusString: String) -> (topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) {
        let components = radiusString.split(separator: " ").map { String($0) }
        
        switch components.count {
        case 1:
            // Single value: all corners
            let value = parseFloat(components[0])
            return (topLeft: value, topRight: value, bottomRight: value, bottomLeft: value)
        case 2:
            // Two values: topLeft/bottomRight, topRight/bottomLeft
            let value1 = parseFloat(components[0])
            let value2 = parseFloat(components[1])
            return (topLeft: value1, topRight: value2, bottomRight: value1, bottomLeft: value2)
        case 4:
            // Four values: topLeft, topRight, bottomRight, bottomLeft (not CSS order - backend specific)
            let topLeft = parseFloat(components[0])     // lewy górny
            let topRight = parseFloat(components[1])    // prawy górny  
            let bottomRight = parseFloat(components[2]) // prawy dolny
            let bottomLeft = parseFloat(components[3])  // lewy dolny
            return (topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
        default:
            // Invalid format - return zero
            return (topLeft: 0, topRight: 0, bottomRight: 0, bottomLeft: 0)
        }
    }
    
    /// Apply border radius with CACornerMask support for individual corners (iOS 11+)
    /// Note: CALayer limitation - different radius per corner not possible, fallback to average
    public static func applyBorderRadius(to view: UIView, radiusString: String) {
        let borderRadius = parseBorderRadius(radiusString)
        
        // Check if all corners have the same radius
        if borderRadius.topLeft == borderRadius.topRight &&
           borderRadius.topRight == borderRadius.bottomRight &&
           borderRadius.bottomRight == borderRadius.bottomLeft {
            // All corners are the same - use simple cornerRadius
            view.layer.cornerRadius = borderRadius.topLeft
            view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            // Different corners - CALayer limitation: can't have different radius per corner
            // Use minimum non-zero radius to avoid oversized corners
            let nonZeroValues = [borderRadius.topLeft, borderRadius.topRight, borderRadius.bottomRight, borderRadius.bottomLeft].filter { $0 > 0 }
            let minRadius = nonZeroValues.isEmpty ? 0 : nonZeroValues.min() ?? 0
            
            view.layer.cornerRadius = minRadius
            
            // Build maskedCorners based on which corners should be rounded
            var maskedCorners: CACornerMask = []
            
            if borderRadius.topLeft > 0 {
                maskedCorners.insert(.layerMinXMinYCorner)
            }
            if borderRadius.topRight > 0 {
                maskedCorners.insert(.layerMaxXMinYCorner)
            }
            if borderRadius.bottomLeft > 0 {
                maskedCorners.insert(.layerMinXMaxYCorner)
            }
            if borderRadius.bottomRight > 0 {
                maskedCorners.insert(.layerMaxXMaxYCorner)
            }
            
            view.layer.maskedCorners = maskedCorners
        }
    }
    
    /// Parse font weight
    public static func parseFontWeight(_ weight: Int) -> UIFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }
    
    /// Parse text alignment
    public static func parseTextAlignment(_ alignment: String) -> NSTextAlignment {
        switch alignment.lowercased() {
        case "center": return .center
        case "right": return .right
        case "left": return .left
        case "justify": return .justified
        default: return .left
        }
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
