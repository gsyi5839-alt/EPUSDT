//
//  ThemeManager.swift
//  EpusdtPay
//
//  Theme management system - supports multiple themes with smooth switching
//

import SwiftUI
import UIKit
import Combine

// MARK: - Theme Colors Definition
struct ThemeColors {
    // Background
    let bgPrimary: Color
    let bgSecondary: Color
    let bgCard: Color
    let bgInput: Color
    
    // Accent
    let accent: Color
    let accentText: Color  // Text color on accent background
    
    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    
    // Status
    let statusSuccess: Color
    let statusError: Color
    let statusWarning: Color
    let statusInfo: Color
    
    // Gradient
    let gradientStart: Color
    let gradientEnd: Color
    
    // Misc
    let divider: Color
    let shadow: Color
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable, Identifiable {
    case darkGold = "dark_gold"
    case darkBlue = "dark_blue"
    case darkPurple = "dark_purple"
    case darkGreen = "dark_green"
    case lightClassic = "light_classic"
    case midnight = "midnight"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .darkGold:    return "暗金经典"
        case .darkBlue:    return "深海蓝调"
        case .darkPurple:  return "星空紫韵"
        case .darkGreen:   return "翡翠暗夜"
        case .lightClassic: return "极简白金"
        case .midnight:    return "午夜黑金"
        }
    }
    
    var icon: String {
        switch self {
        case .darkGold:    return "star.fill"
        case .darkBlue:    return "drop.fill"
        case .darkPurple:  return "sparkles"
        case .darkGreen:   return "leaf.fill"
        case .lightClassic: return "sun.max.fill"
        case .midnight:    return "moon.stars.fill"
        }
    }
    
    var previewColors: [Color] {
        let c = colors
        return [c.bgPrimary, c.bgCard, c.accent]
    }
    
    var colors: ThemeColors {
        switch self {
        case .darkGold:
            return ThemeColors(
                bgPrimary:     Color(hex: 0x0f1218),
                bgSecondary:   Color(hex: 0x171c25),
                bgCard:        Color(hex: 0x1e2530),
                bgInput:       Color(hex: 0x222a36),
                accent:        Color(hex: 0xd4af37),
                accentText:    Color(hex: 0x0f1218),
                textPrimary:   Color(hex: 0xe6e6e6),
                textSecondary: Color(hex: 0x999999),
                textMuted:     Color(hex: 0x666666),
                statusSuccess: Color(hex: 0x2ecc71),
                statusError:   Color(hex: 0xe74c3c),
                statusWarning: Color(hex: 0xf39c12),
                statusInfo:    Color(hex: 0x27cae2),
                gradientStart: Color(hex: 0x0f1218),
                gradientEnd:   Color(hex: 0x171c25),
                divider:       Color(hex: 0x2a3444),
                shadow:        Color.black.opacity(0.3)
            )
            
        case .darkBlue:
            return ThemeColors(
                bgPrimary:     Color(hex: 0x0a1628),
                bgSecondary:   Color(hex: 0x0f1f3a),
                bgCard:        Color(hex: 0x162a4a),
                bgInput:       Color(hex: 0x1c3358),
                accent:        Color(hex: 0x4a9eff),
                accentText:    Color.white,
                textPrimary:   Color(hex: 0xe8edf5),
                textSecondary: Color(hex: 0x8899bb),
                textMuted:     Color(hex: 0x5a6a8a),
                statusSuccess: Color(hex: 0x34d399),
                statusError:   Color(hex: 0xf87171),
                statusWarning: Color(hex: 0xfbbf24),
                statusInfo:    Color(hex: 0x60a5fa),
                gradientStart: Color(hex: 0x0a1628),
                gradientEnd:   Color(hex: 0x0f1f3a),
                divider:       Color(hex: 0x1e3a5f),
                shadow:        Color(hex: 0x050d1a).opacity(0.5)
            )
            
        case .darkPurple:
            return ThemeColors(
                bgPrimary:     Color(hex: 0x13111c),
                bgSecondary:   Color(hex: 0x1a1726),
                bgCard:        Color(hex: 0x241f35),
                bgInput:       Color(hex: 0x2c2640),
                accent:        Color(hex: 0xa78bfa),
                accentText:    Color(hex: 0x13111c),
                textPrimary:   Color(hex: 0xede9fe),
                textSecondary: Color(hex: 0x9b8ec4),
                textMuted:     Color(hex: 0x6b5f8a),
                statusSuccess: Color(hex: 0x34d399),
                statusError:   Color(hex: 0xfb7185),
                statusWarning: Color(hex: 0xfbbf24),
                statusInfo:    Color(hex: 0x818cf8),
                gradientStart: Color(hex: 0x13111c),
                gradientEnd:   Color(hex: 0x1a1726),
                divider:       Color(hex: 0x322b4a),
                shadow:        Color(hex: 0x0a0812).opacity(0.5)
            )
            
        case .darkGreen:
            return ThemeColors(
                bgPrimary:     Color(hex: 0x0b1410),
                bgSecondary:   Color(hex: 0x111d16),
                bgCard:        Color(hex: 0x182820),
                bgInput:       Color(hex: 0x1e3228),
                accent:        Color(hex: 0x34d399),
                accentText:    Color(hex: 0x0b1410),
                textPrimary:   Color(hex: 0xe2f0e8),
                textSecondary: Color(hex: 0x7faa92),
                textMuted:     Color(hex: 0x4d7a60),
                statusSuccess: Color(hex: 0x34d399),
                statusError:   Color(hex: 0xf87171),
                statusWarning: Color(hex: 0xfbbf24),
                statusInfo:    Color(hex: 0x67e8f9),
                gradientStart: Color(hex: 0x0b1410),
                gradientEnd:   Color(hex: 0x111d16),
                divider:       Color(hex: 0x1f3c2c),
                shadow:        Color(hex: 0x050a08).opacity(0.5)
            )
            
        case .lightClassic:
            return ThemeColors(
                bgPrimary:     Color(hex: 0xf5f5f7),
                bgSecondary:   Color(hex: 0xeeeef0),
                bgCard:        Color.white,
                bgInput:       Color(hex: 0xf0f0f2),
                accent:        Color(hex: 0xc49b2a),
                accentText:    Color.white,
                textPrimary:   Color(hex: 0x1a1a2e),
                textSecondary: Color(hex: 0x6b6b80),
                textMuted:     Color(hex: 0x9a9aae),
                statusSuccess: Color(hex: 0x22c55e),
                statusError:   Color(hex: 0xef4444),
                statusWarning: Color(hex: 0xf59e0b),
                statusInfo:    Color(hex: 0x3b82f6),
                gradientStart: Color(hex: 0xf8f8fa),
                gradientEnd:   Color(hex: 0xeeeef0),
                divider:       Color(hex: 0xd4d4dc),
                shadow:        Color.black.opacity(0.08)
            )
            
        case .midnight:
            return ThemeColors(
                bgPrimary:     Color(hex: 0x050505),
                bgSecondary:   Color(hex: 0x0a0a0a),
                bgCard:        Color(hex: 0x141414),
                bgInput:       Color(hex: 0x1a1a1a),
                accent:        Color(hex: 0xf0c040),
                accentText:    Color.black,
                textPrimary:   Color(hex: 0xf0f0f0),
                textSecondary: Color(hex: 0x808080),
                textMuted:     Color(hex: 0x555555),
                statusSuccess: Color(hex: 0x2ecc71),
                statusError:   Color(hex: 0xe74c3c),
                statusWarning: Color(hex: 0xf39c12),
                statusInfo:    Color(hex: 0x3498db),
                gradientStart: Color(hex: 0x050505),
                gradientEnd:   Color(hex: 0x0a0a0a),
                divider:       Color(hex: 0x222222),
                shadow:        Color.black.opacity(0.6)
            )
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "epusdt_app_theme")
        }
    }
    
    var colors: ThemeColors {
        currentTheme.colors
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "epusdt_app_theme") ?? ""
        self.currentTheme = AppTheme(rawValue: saved) ?? .darkGold
        applyUIKitAppearance()
    }
    
    func setTheme(_ theme: AppTheme, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentTheme = theme
            }
        } else {
            currentTheme = theme
        }
        applyUIKitAppearance()
        refreshUIKitViews()
    }
    
    var isDarkMode: Bool {
        currentTheme != .lightClassic
    }
    
    var preferredColorScheme: ColorScheme? {
        currentTheme == .lightClassic ? .light : .dark
    }
    
    // MARK: - UIKit Appearance Configuration
    func applyUIKitAppearance() {
        let colors = currentTheme.colors
        
        // Tab Bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(colors.bgSecondary)
        
        let normalTabItem = UITabBarItemAppearance()
        normalTabItem.normal.iconColor = UIColor(colors.textMuted)
        normalTabItem.normal.titleTextAttributes = [.foregroundColor: UIColor(colors.textMuted)]
        normalTabItem.selected.iconColor = UIColor(colors.accent)
        normalTabItem.selected.titleTextAttributes = [.foregroundColor: UIColor(colors.accent)]
        
        tabBarAppearance.stackedLayoutAppearance = normalTabItem
        tabBarAppearance.inlineLayoutAppearance = normalTabItem
        tabBarAppearance.compactInlineLayoutAppearance = normalTabItem
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Navigation Bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(colors.bgPrimary)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(colors.textPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(colors.textPrimary)]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(colors.accent)
        
        // Segmented Control
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(colors.accent)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(colors.accentText)], for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(colors.textSecondary)], for: .normal
        )
        UISegmentedControl.appearance().backgroundColor = UIColor(colors.bgInput)
    }
    
    // MARK: - Force UIKit Views Refresh
    private func refreshUIKitViews() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            for view in window.subviews {
                view.removeFromSuperview()
                window.addSubview(view)
            }
        }
    }
}
