//
//  ThemeSettingsView.swift
//  EpusdtPay
//
//  Theme selection and preview interface
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.bgPrimary, Color.bgSecondary]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Theme Preview
                    currentThemePreview
                    
                    // Theme Grid
                    themeGrid
                    
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.gold)
            }
            Spacer()
            Text("主题设置")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Current Theme Preview
    private var currentThemePreview: some View {
        VStack(spacing: 16) {
            // Preview Card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: themeManager.currentTheme.icon)
                        .font(.title2)
                        .foregroundColor(.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前主题")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Text(themeManager.currentTheme.displayName)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.gold)
                }
                
                // Color palette preview
                HStack(spacing: 6) {
                    colorSwatch(Color.bgPrimary, label: "背景")
                    colorSwatch(Color.bgCard, label: "卡片")
                    colorSwatch(Color.gold, label: "强调")
                    colorSwatch(Color.textPrimary, label: "文字")
                    colorSwatch(Color.statusSuccess, label: "成功")
                    colorSwatch(Color.statusError, label: "错误")
                }
                
                // Preview components
                HStack(spacing: 8) {
                    Text("USDT 支付系统")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("正常")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.statusSuccess.opacity(0.15))
                        .foregroundColor(.statusSuccess)
                        .cornerRadius(4)
                    Text("TRON")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.statusError.opacity(0.15))
                        .foregroundColor(.statusError)
                        .cornerRadius(4)
                }
            }
            .padding(16)
            .background(Color.bgCard)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Theme Grid
    private var themeGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择主题")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    themeCard(theme)
                }
            }
        }
    }
    
    // MARK: - Theme Card
    private func themeCard(_ theme: AppTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let colors = theme.colors
        
        return Button(action: {
            themeManager.setTheme(theme)
        }) {
            VStack(spacing: 10) {
                // Color preview bar
                HStack(spacing: 0) {
                    colors.bgPrimary
                    colors.bgCard
                    colors.accent
                    colors.textPrimary
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
                .frame(height: 6)
                .cornerRadius(3)
                
                // Mini preview
                VStack(spacing: 4) {
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.accent)
                            .frame(width: 20, height: 4)
                        Spacer()
                        Circle()
                            .fill(colors.statusSuccess)
                            .frame(width: 6, height: 6)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.textPrimary.opacity(0.5))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.textSecondary.opacity(0.3))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(width: 80)
                }
                .padding(8)
                .background(colors.bgCard)
                .cornerRadius(6)
                
                // Name + icon
                HStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 10))
                    Text(theme.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isSelected ? colors.accent : .textSecondary)
            }
            .padding(12)
            .background(isSelected ? Color.gold.opacity(0.08) : Color.bgCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.gold : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Color Swatch
    private func colorSwatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.textSecondary.opacity(0.2), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.textSecondary)
        }
    }
}

#Preview {
    ThemeSettingsView()
        .environmentObject(ThemeManager.shared)
}
