// SharedUIComponents.swift
// Shared UI components for all in-app message templates

import Foundation
import UIKit

/// Shared UI component factory for in-app messages
public class SharedUIComponents {
    
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
        
        return button
    }
    
    /// Create action button with full styling
    public static func createActionButton(for action: InAppMessageAction, actionIndex: Int, extraHeight: CGFloat = 0) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(action.text, for: .normal)
        button.setTitleColor(UIColor(hex: action.textColor), for: .normal)
        button.backgroundColor = UIColor(hex: action.backgroundColor)
        button.layer.borderColor = UIColor(hex: action.borderColor).cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = UIStyleParser.parseFloat(action.borderRadius)
        button.titleLabel?.font = UIFont.systemFont(ofSize: CGFloat(action.fontSize), weight: UIStyleParser.parseFontWeight(action.fontWeight))
        
        // Add padding
        let padding = UIStyleParser.parsePadding(action.padding)
        let adjustedPadding = UIEdgeInsets(
            top: padding.top + extraHeight/2, 
            left: padding.left, 
            bottom: padding.bottom + extraHeight/2, 
            right: padding.right
        )
        button.contentEdgeInsets = adjustedPadding
        
        button.tag = actionIndex
        return button
    }
    
    // MARK: - Label Creation
    
    /// Create title label with font family support
    public static func createTitleLabel(for title: MessageTitle, fontFamily: String? = nil, fontUrl: String? = nil, forceFullWidth: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = title.text
        
        // Use custom font family if provided, otherwise system font
        if let fontFamily = fontFamily, !fontFamily.isEmpty {
            if let customFont = UIFont(name: fontFamily, size: CGFloat(title.fontSize)) {
                label.font = customFont
            } else {
                // Fallback to system font with weight
                label.font = UIFont.systemFont(ofSize: CGFloat(title.fontSize), weight: UIStyleParser.parseFontWeight(title.fontWeight))
                InAppLogger.shared.info("Font '\(fontFamily)' not found, using system font")
                
                // Note: fontUrl support requires font download and registration - not implemented yet
                if let fontUrl = fontUrl, !fontUrl.isEmpty {
                    InAppLogger.shared.info("fontUrl provided: \(fontUrl) - custom font loading not yet implemented")
                }
            }
        } else {
            label.font = UIFont.systemFont(ofSize: CGFloat(title.fontSize), weight: UIStyleParser.parseFontWeight(title.fontWeight))
        }
        
        label.textColor = UIColor(hex: title.color)
        label.textAlignment = UIStyleParser.parseTextAlignment(title.alignment)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    
    /// Create description label with font family support
    public static func createDescriptionLabel(for description: MessageDescription, fontFamily: String? = nil, fontUrl: String? = nil, forceFullWidth: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = description.text
        
        // Use custom font family if provided, otherwise system font
        if let fontFamily = fontFamily, !fontFamily.isEmpty {
            if let customFont = UIFont(name: fontFamily, size: CGFloat(description.fontSize)) {
                label.font = customFont
            } else {
                // Fallback to system font with weight
                label.font = UIFont.systemFont(ofSize: CGFloat(description.fontSize), weight: UIStyleParser.parseFontWeight(description.fontWeight))
                InAppLogger.shared.info("Font '\(fontFamily)' not found, using system font")
                
                // Note: fontUrl support requires font download and registration - not implemented yet
                if let fontUrl = fontUrl, !fontUrl.isEmpty {
                    InAppLogger.shared.info("fontUrl provided: \(fontUrl) - custom font loading not yet implemented")
                }
            }
        } else {
            label.font = UIFont.systemFont(ofSize: CGFloat(description.fontSize), weight: UIStyleParser.parseFontWeight(description.fontWeight))
        }
        
        label.textColor = UIColor(hex: description.color)
        label.textAlignment = UIStyleParser.parseTextAlignment(description.alignment)
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
        
        // Load image asynchronously
        loadImageAsync(from: imageUrl, into: imageView)
        
        // Set height constraint
        imageView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
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
    
    /// Create horizontal actions stack view
    public static func createActionsView(for message: InAppMessage, fillWidth: Bool = false) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add action buttons with extra height for Template 1 (fullscreen)
        let extraHeight: CGFloat = fillWidth ? 12 : 0  // Slightly taller for Template 1
        for (index, action) in message.actions.enumerated() {
            if action.enabled {
                let button = createActionButton(for: action, actionIndex: index, extraHeight: extraHeight)
                stackView.addArrangedSubview(button)
            }
        }
        
        // For Template 1, ensure full width
        if fillWidth {
            stackView.distribution = .fill
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
    
    /// Parse padding string to UIEdgeInsets
    public static func parsePadding(_ paddingString: String) -> UIEdgeInsets {
        let padding = parseFloat(paddingString)
        return UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
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
    
    /// Parse font weight
    public static func parseFontWeight(_ weight: Int) -> UIFont.Weight {
        switch weight {
        case 700...900: return .bold
        case 600: return .semibold
        case 500: return .medium
        case 300: return .light
        case 100...200: return .thin
        default: return .regular
        }
    }
    
    /// Parse text alignment
    public static func parseTextAlignment(_ alignment: String) -> NSTextAlignment {
        switch alignment.lowercased() {
        case "center": return .center
        case "right": return .right
        case "left": return .left
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
