//
//  User.swift
//  EpusdtPay
//
//  User data model - matches backend AdminUser structure
//

import Foundation

struct User: Codable, Identifiable {
    let id: UInt64
    let username: String
    let roleId: UInt64
    let status: Int
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case status
        case roleId = "role_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Wallet Model
struct Wallet: Codable, Identifiable {
    let id: String
    let address: String
    let chain: String // "BSC", "ETHEREUM", "POLYGON", "TRON"
    let connectedDate: Date

    enum CodingKeys: String, CodingKey {
        case id
        case address
        case chain
        case connectedDate = "connected_date"
    }
}

// MARK: - Payment Model
struct Payment: Codable, Identifiable {
    let id: String
    let amount: Double
    let merchantWallet: String
    let chain: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case merchantWallet = "merchant_wallet"
        case chain
        case createdAt = "created_at"
    }
}

// MARK: - Transaction Model
struct Transaction: Codable, Identifiable {
    let id: String
    let paymentId: String
    let amount: Double
    let chain: String
    let status: String // "pending", "completed", "failed"
    let transactionHash: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case paymentId = "payment_id"
        case amount
        case chain
        case status
        case transactionHash = "transaction_hash"
        case createdAt = "created_at"
    }
}

// MARK: - QR Code Data
struct QRCodeData: Codable {
    let merchantWallet: String
    let amount: Double
    let chain: String
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case merchantWallet = "merchant_wallet"
        case amount
        case chain
        case timestamp
    }
}
