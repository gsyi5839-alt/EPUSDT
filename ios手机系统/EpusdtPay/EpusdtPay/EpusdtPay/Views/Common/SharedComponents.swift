//
//  SharedComponents.swift
//  EpusdtPay
//
//  Reusable UI components with dark theme and gold accent
//

import SwiftUI

// MARK: - Color Extension (Theme-Aware)
extension Color {
    private static var theme: ThemeColors { ThemeManager.shared.colors }
    
    static var bgPrimary: Color     { theme.bgPrimary }
    static var bgSecondary: Color   { theme.bgSecondary }
    static var bgCard: Color        { theme.bgCard }
    static var bgInput: Color       { theme.bgInput }
    static var gold: Color          { theme.accent }
    static var accentText: Color    { theme.accentText }
    static var textPrimary: Color   { theme.textPrimary }
    static var textSecondary: Color { theme.textSecondary }
    static var textMuted: Color     { theme.textMuted }
    static var statusSuccess: Color { theme.statusSuccess }
    static var statusError: Color   { theme.statusError }
    static var statusWarning: Color { theme.statusWarning }
    static var statusInfo: Color    { theme.statusInfo }
    static var dividerColor: Color  { theme.divider }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .gold

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .frame(width: 140)
        .background(Color.bgCard)
        .cornerRadius(12)
    }
}

// MARK: - Form Field
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(12)
                .background(Color.bgInput)
                .foregroundColor(.textPrimary)
                .cornerRadius(8)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
}

// MARK: - Gold Button
struct GoldButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentText))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(isLoading ? Color.gold.opacity(0.5) : Color.gold)
            .foregroundColor(Color.accentText)
            .cornerRadius(8)
        }
        .disabled(isLoading)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color

    init(authStatus: Int) {
        switch authStatus {
        case 1: self.text = "待授权"; self.color = .statusWarning
        case 2: self.text = "有效"; self.color = .statusSuccess
        case 3: self.text = "已撤销"; self.color = .statusError
        case 4: self.text = "已用尽"; self.color = .textSecondary
        default: self.text = "未知"; self.color = .textSecondary
        }
    }

    init(deductStatus: Int) {
        switch deductStatus {
        case 1: self.text = "处理中"; self.color = .statusWarning
        case 2: self.text = "成功"; self.color = .statusSuccess
        case 3: self.text = "失败"; self.color = .statusError
        default: self.text = "未知"; self.color = .textSecondary
        }
    }

    init(orderStatus: Int) {
        switch orderStatus {
        case 1: self.text = "待支付"; self.color = .statusWarning
        case 2: self.text = "已支付"; self.color = .statusSuccess
        case 3: self.text = "已过期"; self.color = .textSecondary
        default: self.text = "未知"; self.color = .textSecondary
        }
    }

    init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Chain Badge
struct ChainBadge: View {
    let chain: String?

    var chainName: String {
        switch chain?.lowercased() {
        case "tron": return "TRON"
        case "bsc": return "BSC"
        case "eth": return "ETH"
        case "polygon": return "Polygon"
        default: return chain?.uppercased() ?? "TRON"
        }
    }

    var chainColor: Color {
        switch chain?.lowercased() {
        case "tron": return .statusError
        case "bsc": return .statusWarning
        case "eth": return .statusInfo
        case "polygon": return Color(hex: 0x8247e5)
        default: return .textSecondary
        }
    }

    var body: some View {
        Text(chainName)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chainColor.opacity(0.15))
            .foregroundColor(chainColor)
            .cornerRadius(4)
    }
}

// MARK: - Chain Picker
struct ChainPicker: View {
    @Binding var selected: String
    let chains = ["tron", "bsc", "eth", "polygon"]
    let labels = ["TRON", "BSC", "ETH", "Polygon"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("区块链网络")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Picker("链", selection: $selected) {
                ForEach(Array(zip(chains, labels)), id: \.0) { chain, label in
                    Text(label).tag(chain)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.statusError)
            Text(message)
                .font(.caption)
                .foregroundColor(.statusError)
            Spacer()
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(10)
        .background(Color.statusError.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Success Banner
struct SuccessBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.statusSuccess)
            Text(message)
                .font(.caption)
                .foregroundColor(.statusSuccess)
            Spacer()
        }
        .padding(10)
        .background(Color.statusSuccess.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Themed Background Modifier
struct DarkBackground: ViewModifier {
    func body(content: Content) -> some View {
        let theme = ThemeManager.shared.colors
        content
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [theme.gradientStart, theme.gradientEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func darkBackground() -> some View {
        self.modifier(DarkBackground())
    }
    
    func themedBackground() -> some View {
        self.modifier(DarkBackground())
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .textPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }
}
