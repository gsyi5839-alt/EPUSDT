//
//  Constants.swift
//  EpusdtPay
//
//  Application constants and configuration
//

import Foundation
import UIKit

// MARK: - API Configuration
struct APIConfig {
    static let baseURL = "http://localhost:8000"
    static let timeout: TimeInterval = 30.0
    static let maxRetries = 3
}

// MARK: - App Configuration
struct AppConfig {
    static let appName = "Epusdt Pay"
    static let version = "1.0.0"
    static let bundleIdentifier = "com.epusdt.pay"
    static let minimumOSVersion = "14.0"
}

// MARK: - Blockchain Networks
struct BlockchainConfig {
    static let supportedChains = ["BSC", "Ethereum", "Polygon", "TRON"]

    static let chainRPCs: [String: String] = [
        "BSC": "https://bsc-dataseed.binance.org/",
        "Ethereum": "https://eth.llamarpc.com/",
        "Polygon": "https://polygon-rpc.com/",
        "TRON": "https://api.trongrid.io/"
    ]

    static let usdtContracts: [String: String] = [
        "BSC": "0x55d398326f99059fF775485246999027B3197955",
        "Ethereum": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        "Polygon": "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
        "TRON": "TR7NHqjeKQxGTCi8q282RJWC3SVrFoJypL"
    ]
}

// MARK: - Color Scheme
struct ColorScheme {
    // Primary Colors
    static let primary = UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1.0) // #d4af37
    static let primaryDark = UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0) // #0f1218

    // Secondary Colors
    static let card = UIColor(red: 0.09, green: 0.11, blue: 0.145, alpha: 1.0) // #171c25
    static let border = UIColor(red: 0.165, green: 0.204, blue: 0.267, alpha: 1.0) // #2a3444

    // Text Colors
    static let textPrimary = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0) // #e6e6e6
    static let textSecondary = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // #999999

    // Status Colors
    static let success = UIColor(red: 0.18, green: 0.8, blue: 0.443, alpha: 1.0) // #2ecc71
    static let error = UIColor(red: 0.906, green: 0.298, blue: 0.235, alpha: 1.0) // #e74c3c
    static let warning = UIColor(red: 0.956, green: 0.576, blue: 0.157, alpha: 1.0) // #f39c12
    static let info = UIColor(red: 0.157, green: 0.792, blue: 0.902, alpha: 1.0) // #27cae2
}

// MARK: - UI Constants
struct UIConstants {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // Corner Radius
    static let cornerRadiusSmall: CGFloat = 4
    static let cornerRadiusMedium: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 12

    // Font Sizes
    static let fontSizeXS: CGFloat = 10
    static let fontSizeS: CGFloat = 12
    static let fontSizeM: CGFloat = 14
    static let fontSizeL: CGFloat = 16
    static let fontSizeXL: CGFloat = 18
    static let fontSizeTitle: CGFloat = 24

    // Button
    static let buttonHeight: CGFloat = 48
    static let buttonCornerRadius: CGFloat = 8
}

// MARK: - Keychain Keys
struct KeychainKeys {
    static let authToken = "com.epusdt.authToken"
    static let userId = "com.epusdt.userId"
    static let userPhone = "com.epusdt.userPhone"
    static let walletAddress = "com.epusdt.walletAddress"
}

// MARK: - User Defaults Keys
struct UserDefaultsKeys {
    static let isLoggedIn = "isLoggedIn"
    static let lastLoginDate = "lastLoginDate"
    static let preferredLanguage = "preferredLanguage"
    static let theme = "theme"
}

// MARK: - Error Messages
struct ErrorMessages {
    static let invalidURL = "Invalid URL"
    static let networkError = "Network connection error. Please check your internet connection."
    static let serverError = "Server error. Please try again later."
    static let invalidCredentials = "Invalid phone number or password"
    static let userAlreadyExists = "User already exists"
    static let passwordMismatch = "Passwords do not match"
    static let invalidWallet = "Invalid wallet address"
    static let insufficientBalance = "Insufficient balance"
    static let transactionFailed = "Transaction failed"
}

// MARK: - Validation Rules
struct ValidationRules {
    static let minPasswordLength = 8
    static let maxPasswordLength = 50
    static let phoneNumberLength = 11 // China: +86
    static let walletAddressLength = 42 // Ethereum: 0x + 40 hex
}

// MARK: - API Endpoints
struct APIEndpoints {
    // Authentication
    static let login = "/admin/api/login"
    static let logout = "/admin/api/logout"
    static let profile = "/admin/api/me"

    // Wallet
    static let walletList = "/api/v1/wallet/list"
    static let addWallet = "/api/v1/wallet/add"
    static let updateWallet = "/api/v1/wallet/update-status"
    static let deleteWallet = "/api/v1/wallet/delete"

    // Payment
    static let createOrder = "/api/v1/order/create-transaction"
    static let checkStatus = "/api/v1/order/check-status"
    static let paymentHistory = "/api/v1/payment/history"

    // QR Code
    static let generateQRCode = "/api/v1/tool/qrcode"
    static let qrcodeStream = "/api/v1/qrcode"
}
