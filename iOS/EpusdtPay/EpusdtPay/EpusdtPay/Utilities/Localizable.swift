//
//  Localizable.swift
//  EpusdtPay
//
//  Localization support for multiple languages
//

import Foundation

enum LocalizableString {
    // MARK: - Common
    case appName
    case ok
    case cancel
    case confirm
    case back
    case done
    case loading
    case error
    case success

    // MARK: - Authentication
    case login
    case logout
    case username
    case password
    case loginButton
    case loginFailed
    case loginSuccess

    // MARK: - Customer
    case scanQRCode
    case scanToAuthorize
    case authorizationRequest
    case confirmAuthorization
    case myAuthorizations
    case walletAddress
    case enterWalletAddress
    case authorized
    case used
    case remaining
    case activeAuthorizations
    case totalAuthorized

    // MARK: - Merchant
    case dashboard
    case createAuthorization
    case deduct
    case query
    case amount
    case tableNo
    case customerName
    case remark
    case authorizationNo
    case passwordCredential
    case merchantWallet

    // MARK: - General
    case chain
    case status
    case details
    case history
    case viewAll
    case refresh

    var localized: String {
        switch self {
        // Common
        case .appName: return NSLocalizedString("app_name", comment: "")
        case .ok: return NSLocalizedString("ok", comment: "")
        case .cancel: return NSLocalizedString("cancel", comment: "")
        case .confirm: return NSLocalizedString("confirm", comment: "")
        case .back: return NSLocalizedString("back", comment: "")
        case .done: return NSLocalizedString("done", comment: "")
        case .loading: return NSLocalizedString("loading", comment: "")
        case .error: return NSLocalizedString("error", comment: "")
        case .success: return NSLocalizedString("success", comment: "")

        // Authentication
        case .login: return NSLocalizedString("login", comment: "")
        case .logout: return NSLocalizedString("logout", comment: "")
        case .username: return NSLocalizedString("username", comment: "")
        case .password: return NSLocalizedString("password", comment: "")
        case .loginButton: return NSLocalizedString("login_button", comment: "")
        case .loginFailed: return NSLocalizedString("login_failed", comment: "")
        case .loginSuccess: return NSLocalizedString("login_success", comment: "")

        // Customer
        case .scanQRCode: return NSLocalizedString("scan_qr_code", comment: "")
        case .scanToAuthorize: return NSLocalizedString("scan_to_authorize", comment: "")
        case .authorizationRequest: return NSLocalizedString("authorization_request", comment: "")
        case .confirmAuthorization: return NSLocalizedString("confirm_authorization", comment: "")
        case .myAuthorizations: return NSLocalizedString("my_authorizations", comment: "")
        case .walletAddress: return NSLocalizedString("wallet_address", comment: "")
        case .enterWalletAddress: return NSLocalizedString("enter_wallet_address", comment: "")
        case .authorized: return NSLocalizedString("authorized", comment: "")
        case .used: return NSLocalizedString("used", comment: "")
        case .remaining: return NSLocalizedString("remaining", comment: "")
        case .activeAuthorizations: return NSLocalizedString("active_authorizations", comment: "")
        case .totalAuthorized: return NSLocalizedString("total_authorized", comment: "")

        // Merchant
        case .dashboard: return NSLocalizedString("dashboard", comment: "")
        case .createAuthorization: return NSLocalizedString("create_authorization", comment: "")
        case .deduct: return NSLocalizedString("deduct", comment: "")
        case .query: return NSLocalizedString("query", comment: "")
        case .amount: return NSLocalizedString("amount", comment: "")
        case .tableNo: return NSLocalizedString("table_no", comment: "")
        case .customerName: return NSLocalizedString("customer_name", comment: "")
        case .remark: return NSLocalizedString("remark", comment: "")
        case .authorizationNo: return NSLocalizedString("authorization_no", comment: "")
        case .passwordCredential: return NSLocalizedString("password_credential", comment: "")
        case .merchantWallet: return NSLocalizedString("merchant_wallet", comment: "")

        // General
        case .chain: return NSLocalizedString("chain", comment: "")
        case .status: return NSLocalizedString("status", comment: "")
        case .details: return NSLocalizedString("details", comment: "")
        case .history: return NSLocalizedString("history", comment: "")
        case .viewAll: return NSLocalizedString("view_all", comment: "")
        case .refresh: return NSLocalizedString("refresh", comment: "")
        }
    }
}

// MARK: - Extension for easier access
extension String {
    static func localized(_ key: LocalizableString) -> String {
        return key.localized
    }
}
