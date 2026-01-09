import UIKit
import CoreText

/// Clean FontManager for bundled fonts with backend weight mapping (100-900)
internal class FontManager {
    static let shared = FontManager()
    
    // Properties
    private var registeredFonts: Set<String> = []
    private let fontCache = NSCache<NSString, UIFont>()
    
    // Backend weight (100-900) to font variant mapping
    private let weightMap: [Int: String] = [
        100: "Thin",
        200: "ExtraLight", 
        300: "Light",
        400: "Regular",
        500: "Medium",
        600: "SemiBold",
        700: "Bold",
        800: "ExtraBold",
        900: "Black"
    ]
    
    // Font families with folder structures (using iOS family names)
    private let fontStructures: [String: FontStructure] = [
        "Fira Sans": .direct,
        "Inter": .static,           // Backend sends 'Inter' -> default to Inter 18pt
        "Inter 18pt": .static,
        "Inter 24pt": .static, 
        "Inter 28pt": .static,
        "Lato": .direct,
        "Montserrat": .static,
        "Open Sans": .static,
        "Open Sans Condensed": .static,
        "Open Sans SemiCondensed": .static,
        "Playfair Display": .static,
        "Poppins": .direct,
        "Roboto": .static,
        "Roboto Condensed": .static,
        "Roboto SemiCondensed": .static
    ]
    
    // Only Arial and Georgia system fonts supported
    private let systemFonts: Set<String> = ["Arial", "Georgia"]
    
    private enum FontStructure {
        case direct    // TTF files in family folder
        case `static`  // TTF files in /static subfolder
    }
    
    // Initialization
    
    private init() {
        registerAllBundledFonts()
    }
    
    // Public API
    
    /// Load font with backend parameters (weight: 100-900, style: "normal"/"italic")
    func loadFont(family: String, size: CGFloat, weight: Int, style: String = "normal") -> UIFont {
        let cacheKey = "\(family)-\(size)-\(weight)-\(style)" as NSString
        
        if let cached = fontCache.object(forKey: cacheKey) {
            return cached
        }
        
        let font = createFont(family: family, size: size, weight: weight, style: style)
        fontCache.setObject(font, forKey: cacheKey)
        return font
    }
    
    // Font Creation
    
    private func createFont(family: String, size: CGFloat, weight: Int, style: String) -> UIFont {
        // System fonts (only Arial, Georgia)
        if systemFonts.contains(family) {
            return createSystemFont(family: family, size: size, weight: weight, style: style)
        }
        
        // Bundled fonts
        if fontStructures.keys.contains(family) {
            return createBundledFont(family: family, size: size, weight: weight, style: style)
        }
        
        // Unknown font -> system fallback
        return UIFont.systemFont(ofSize: size)
    }
    
    private func createSystemFont(family: String, size: CGFloat, weight: Int, style: String) -> UIFont {
        let fontName = buildSystemFontName(family: family, weight: weight, style: style)
        
        if let font = UIFont(name: fontName, size: size) {
            return font
        }
        
        // Fallback with UIFont.Weight
        let uiWeight = mapWeightToUIFontWeight(weight)
        return UIFont.systemFont(ofSize: size, weight: uiWeight)
    }
    
    private func createBundledFont(family: String, size: CGFloat, weight: Int, style: String) -> UIFont {
        let fontName = buildBundledFontName(family: family, weight: weight, style: style)
        
        if let font = UIFont(name: fontName, size: size) {
            return font
        }
        
        // Try fallback variants in the same family
        if let fallbackFont = findFallbackFontInFamily(family: family, originalWeight: weight, style: style, size: size) {
            return fallbackFont
        }

        let uiWeight = mapWeightToUIFontWeight(weight)
        return UIFont.systemFont(ofSize: size, weight: uiWeight)
    }
    
    private func findFallbackFontInFamily(family: String, originalWeight: Int, style: String, size: CGFloat) -> UIFont? {
        let baseFamily = mapFamilyToFontName(family)
        let isItalic = style.lowercased() == "italic"
        let allWeights = weightMap.keys.sorted()
        
        // Try weights in order of proximity to original weight
        let sortedByProximity = allWeights.sorted { abs($0 - originalWeight) < abs($1 - originalWeight) }
        
        for weight in sortedByProximity {
            // Skip original weight we already tried
            if weight == originalWeight {
                continue
            }
            
            let fallbackVariant = weightMap[weight] ?? "Regular"
            let adjustedVariant = adjustVariantForFamily(variant: fallbackVariant, family: family)
            let fallbackFontName = "\(baseFamily)-\(adjustedVariant)\(isItalic ? "Italic" : "")"
            
            if let font = UIFont(name: fallbackFontName, size: size) {
                return font
            }
        }
        
        return nil
    }
    
    // Font Name Building
    
    private func buildSystemFontName(family: String, weight: Int, style: String) -> String {
        let isItalic = style.lowercased() == "italic"
        let isBold = weight >= 500
        
        switch family {
        case "Arial":
            switch (isBold, isItalic) {
            case (true, true): return "Arial-BoldItalicMT"
            case (true, false): return "Arial-BoldMT"
            case (false, true): return "Arial-ItalicMT"
            case (false, false): return "ArialMT"
            }
        case "Georgia":
            switch (isBold, isItalic) {
            case (true, true): return "Georgia-BoldItalic"
            case (true, false): return "Georgia-Bold"
            case (false, true): return "Georgia-Italic"
            case (false, false): return "Georgia"
            }
        default:
            return family
        }
    }
    
    private func buildBundledFontName(family: String, weight: Int, style: String) -> String {
        let baseFamily = mapFamilyToFontName(family)
        let weightVariant = findClosestWeightVariant(weight: weight, family: family)
        let isItalic = style.lowercased() == "italic"
        
        return "\(baseFamily)-\(weightVariant)\(isItalic ? "Italic" : "")"
    }
    
    private func mapFamilyToFontName(_ family: String) -> String {
        // Map iOS family names to PostScript font prefixes
        switch family {
        case "Fira Sans": return "FiraSans"
        case "Inter": return "Inter18pt"              // Default Inter to 18pt variant
        case "Inter 18pt": return "Inter18pt"
        case "Inter 24pt": return "Inter24pt"
        case "Inter 28pt": return "Inter28pt"
        case "Lato": return "Lato"
        case "Montserrat": return "Montserrat"
        case "Open Sans": return "OpenSans"
        case "Open Sans Condensed": return "OpenSansCondensed"
        case "Open Sans SemiCondensed": return "OpenSansSemiCondensed"
        case "Playfair Display": return "PlayfairDisplay"
        case "Poppins": return "Poppins"
        case "Roboto": return "Roboto"
        case "Roboto Condensed": return "RobotoCondensed"
        case "Roboto SemiCondensed": return "RobotoSemiCondensed"
        default: return family.replacingOccurrences(of: " ", with: "")
        }
    }
    
    private func findClosestWeightVariant(weight: Int, family: String) -> String {
        let availableWeights = weightMap.keys.sorted()
        let closestWeight = availableWeights.min { abs($0 - weight) < abs($1 - weight) } ?? 400
        let variant = weightMap[closestWeight] ?? "Regular"
        
        // Handle fonts with limited variants
        return adjustVariantForFamily(variant: variant, family: family)
    }
    
    private func adjustVariantForFamily(variant: String, family: String) -> String {
        // Playfair Display doesn't have light variants
        if family == "Playfair_Display" {
            switch variant {
            case "Thin", "ExtraLight", "Light":
                return "Regular"
            default:
                return variant
            }
        }
        
        return variant
    }
    
    private func mapWeightToUIFontWeight(_ weight: Int) -> UIFont.Weight {
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
    
    // Font Registration
    
    private func registerAllBundledFonts() {
        for (family, structure) in fontStructures {
            registerFontFamily(family, structure: structure)
        }
        
        InAppLogger.shared.debug("Registered \(registeredFonts.count) fonts")
    }
    
    private func registerFontFamily(_ family: String, structure: FontStructure) {
        guard let bundle = getBundle() else { return }
        
        let searchPath = buildSearchPath(family: family, structure: structure)
        let fontPaths = bundle.paths(forResourcesOfType: "ttf", inDirectory: searchPath)
        
        // Try alternative paths if main search fails
        if fontPaths.isEmpty {
            let internalFamily = mapToInternalFontName(family)
            let alternativePaths = [
                "Fonts/\(internalFamily)",
                "Fonts/\(internalFamily)/static",
                internalFamily,
                "\(internalFamily)/static"
            ]
            
            for altPath in alternativePaths {
                let altFonts = bundle.paths(forResourcesOfType: "ttf", inDirectory: altPath)
                if !altFonts.isEmpty {
                    for path in altFonts {
                        registerSingleFont(at: path)
                    }
                    return
                }
            }
        } else {
            for path in fontPaths {
                registerSingleFont(at: path)
            }
        }
    }
    
    private func buildSearchPath(family: String, structure: FontStructure) -> String {
        // Convert backend name to internal folder name
        let internalFamily = mapToInternalFontName(family)
        let basePath = "Fonts/\(internalFamily)"
        switch structure {
        case .direct:
            return basePath
        case .static:
            return "\(basePath)/static"
        }
    }
    
    private func mapToInternalFontName(_ iOSFamilyName: String) -> String {
        // Convert iOS family names to folder names (folders use underscores)
        switch iOSFamilyName {
        case "Playfair Display": return "Playfair_Display"
        case "Fira Sans": return "Fira_Sans" 
        case "Open Sans": return "Open_Sans"
        case "Open Sans Condensed": return "Open_Sans"
        case "Open Sans SemiCondensed": return "Open_Sans"
        case "Inter 18pt", "Inter 24pt", "Inter 28pt": return "Inter"
        case "Roboto Condensed", "Roboto SemiCondensed": return "Roboto"
        default: return iOSFamilyName
        }
    }
    
    private func registerSingleFont(at path: String) {
        guard let fontData = NSData(contentsOfFile: path),
              let provider = CGDataProvider(data: fontData),
              let cgFont = CGFont(provider) else { return }
        
        // Check if font is already registered to avoid system warnings
        if let postScriptName = cgFont.postScriptName {
            let postScriptString = postScriptName as String
            
            // Skip if already registered by us
            if registeredFonts.contains(postScriptString) {
                return
            }
            
            // Skip if already available in system
            if UIFont(name: postScriptString, size: 12) != nil {
                registeredFonts.insert(postScriptString) // Mark as known
                return
            }
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(cgFont, &error)
        
        if success, let postScriptName = cgFont.postScriptName {
            registeredFonts.insert(postScriptName as String)
        } else if let error = error {
            let cfError = error.takeUnretainedValue()
            let code = CFErrorGetCode(cfError)
            
            // Ignore "already registered" errors: 105 = already registered, 305 = font exists
            if code != 105 && code != 305 {
                InAppLogger.shared.debug("Font registration failed: \(CFErrorCopyDescription(cfError) ?? "" as CFString)")
            }
        }
    }
    
    private func getBundle() -> Bundle? {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        // For CocoaPods: look for resource bundle created by resource_bundles in podspec
        let containerBundle = Bundle(for: FontManager.self)
        
        // Try to find the resource bundle (PPG_InAppMessages.bundle)
        if let resourceBundleURL = containerBundle.url(forResource: "PPG_InAppMessages", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            return resourceBundle
        }
        
        // Fallback: try to find in main bundle (for Flutter/React Native integrations)
        if let mainResourceBundleURL = Bundle.main.url(forResource: "PPG_InAppMessages", withExtension: "bundle"),
           let mainResourceBundle = Bundle(url: mainResourceBundleURL) {
            return mainResourceBundle
        }
        
        // Last resort: use container bundle directly
        return containerBundle
        #endif
    }
    
    // Cache Management
    
    func clearCache() {
        fontCache.removeAllObjects()
    }
}
