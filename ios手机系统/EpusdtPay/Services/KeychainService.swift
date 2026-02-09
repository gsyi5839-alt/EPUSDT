//
//  KeychainService.swift
//  EpusdtPay
//
//  Secure storage for authentication tokens and sensitive data
//  Uses iOS Keychain (encrypted by OS)
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.epusdt.epusdtpay"

    private init() {}

    // MARK: - Generic Methods

    /// Save a value to Keychain
    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing value first
        SecItemDelete(query as CFDictionary)

        // Add new value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.savingError(status: status)
        }
    }

    /// Retrieve a value from Keychain
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Delete a value from Keychain
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletingError(status: status)
        }
    }

    /// Clear all stored values from Keychain
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience Methods for Auth

    /// Save authentication token
    func saveToken(_ token: String) throws {
        try save(key: KeychainKeys.authToken, value: token)
    }

    /// Retrieve authentication token
    func getToken() -> String? {
        get(key: KeychainKeys.authToken)
    }

    /// Delete authentication token
    func deleteToken() throws {
        try delete(key: KeychainKeys.authToken)
    }

    /// Save user ID
    func saveUserId(_ userId: String) throws {
        try save(key: KeychainKeys.userId, value: userId)
    }

    /// Retrieve user ID
    func getUserId() -> String? {
        get(key: KeychainKeys.userId)
    }

    /// Save user phone number
    func saveUserPhone(_ phone: String) throws {
        try save(key: KeychainKeys.userPhone, value: phone)
    }

    /// Retrieve user phone number
    func getUserPhone() -> String? {
        get(key: KeychainKeys.userPhone)
    }

    /// Save wallet address
    func saveWalletAddress(_ address: String) throws {
        try save(key: KeychainKeys.walletAddress, value: address)
    }

    /// Retrieve wallet address
    func getWalletAddress() -> String? {
        get(key: KeychainKeys.walletAddress)
    }
}

// MARK: - Error Handling

enum KeychainError: LocalizedError {
    case encodingError
    case savingError(status: OSStatus)
    case deletingError(status: OSStatus)
    case retrievalError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Failed to encode value"
        case .savingError(let status):
            return "Failed to save to Keychain (Status: \(status))"
        case .deletingError(let status):
            return "Failed to delete from Keychain (Status: \(status))"
        case .retrievalError(let status):
            return "Failed to retrieve from Keychain (Status: \(status))"
        }
    }
}
