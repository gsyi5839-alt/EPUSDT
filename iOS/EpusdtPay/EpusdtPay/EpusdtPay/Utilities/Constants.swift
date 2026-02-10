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
    static let baseURL = "https://bocail.com"
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
    // Admin Authentication
    static let adminLogin = "/admin/api/login"
    static let adminLogout = "/admin/api/logout"
    static let adminProfile = "/admin/api/me"
    static let adminUsers = "/admin/api/users"
    static let adminRoles = "/admin/api/roles"
    static let adminOrders = "/admin/api/orders"
    static let adminOrderDetail = "/admin/api/order"  // + /:trade_id
    static let adminAuthorizations = "/admin/api/authorizations"
    static let adminDeductions = "/admin/api/deductions"
    static let adminCallbacks = "/admin/api/callbacks"
    static let adminMerchants = "/admin/api/merchants"
    static let adminMerchantsBan = "/admin/api/merchants/ban"
    static let adminWallets = "/admin/api/wallets"

    // Merchant Authentication
    static let merchantRegister = "/api/v1/merchant/register"
    static let merchantLogin = "/api/v1/merchant/login"
    static let merchantProfile = "/api/v1/merchant/profile"

    // Merchant Business
    static let merchantQRCode = "/api/v1/merchant/qrcode"
    static let merchantAuthorizations = "/api/v1/merchant/authorizations"
    static let merchantDeductions = "/api/v1/merchant/deductions"
    static let merchantStatsSummary = "/api/v1/merchant/stats/summary"
    static let merchantStatsChart = "/api/v1/merchant/stats/chart"
    static let merchantWallets = "/api/v1/merchant/wallets"
    static let merchantWalletsStatus = "/api/v1/merchant/wallets/status"

    // Authorization Payment (public)
    static let authCreate = "/api/v1/auth/create"
    static let authConfirm = "/api/v1/auth/confirm"
    static let authConfirmAuto = "/api/v1/auth/confirm-auto"
    static let authDeduct = "/api/v1/auth/deduct"
    static let authInfo = "/api/v1/auth/info"   // + /:password
    static let authHistory = "/api/v1/auth/history"  // + /:password
    static let authList = "/api/v1/auth/list"

    // Order
    static let createOrder = "/api/v1/order/create-transaction"
    static let checkStatus = "/pay/check-status"  // + /:trade_id

    // Wallet (signed API)
    static let walletAdd = "/api/v1/wallet/add"
    static let walletList = "/api/v1/wallet/list"
    static let walletUpdateStatus = "/api/v1/wallet/update-status"
    static let walletDelete = "/api/v1/wallet/delete"

    // Tools
    static let generateQRCode = "/api/v1/tool/qrcode"
    static let qrcodeStream = "/qrcode"
}
