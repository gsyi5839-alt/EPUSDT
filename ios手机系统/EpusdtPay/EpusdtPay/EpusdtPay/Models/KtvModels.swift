//
//  KtvModels.swift
//  EpusdtPay
//
//  Data models for KTV authorization payment system
//

import Foundation

// MARK: - KTV Authorization
struct KtvAuthorization: Codable, Identifiable {
    let id: UInt64
    let authNo: String
    let password: String?
    let customerWallet: String?
    let merchantWallet: String?
    let chain: String?
    let authorizedUsdt: Double
    let usedUsdt: Double
    let remainingUsdt: Double
    let status: Int
    let tableNo: String?
    let customerName: String?
    let txHash: String?
    let authorizeTime: Int64?
    let expireTime: Int64?
    let remark: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case authNo = "auth_no"
        case password
        case customerWallet = "customer_wallet"
        case merchantWallet = "merchant_wallet"
        case chain
        case authorizedUsdt = "authorized_usdt"
        case usedUsdt = "used_usdt"
        case remainingUsdt = "remaining_usdt"
        case status
        case tableNo = "table_no"
        case customerName = "customer_name"
        case txHash = "tx_hash"
        case authorizeTime = "authorize_time"
        case expireTime = "expire_time"
        case remark
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusText: String {
        switch status {
        case 1: return "待授权"
        case 2: return "有效"
        case 3: return "已撤销"
        case 4: return "已用尽"
        default: return "未知"
        }
    }
}

// MARK: - KTV Deduction
struct KtvDeduction: Codable, Identifiable {
    let id: UInt64
    let deductNo: String
    let authId: UInt64?
    let authNo: String?
    let password: String?
    let amountUsdt: Double
    let amountCny: Double
    let txHash: String?
    let status: Int
    let failReason: String?
    let productInfo: String?
    let operatorId: String?
    let deductTime: Int64?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deductNo = "deduct_no"
        case authId = "auth_id"
        case authNo = "auth_no"
        case password
        case amountUsdt = "amount_usdt"
        case amountCny = "amount_cny"
        case txHash = "tx_hash"
        case status
        case failReason = "fail_reason"
        case productInfo = "product_info"
        case operatorId = "operator_id"
        case deductTime = "deduct_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusText: String {
        switch status {
        case 1: return "处理中"
        case 2: return "成功"
        case 3: return "失败"
        default: return "未知"
        }
    }
}

// MARK: - Order
struct Order: Codable, Identifiable {
    let id: UInt64
    let tradeId: String
    let orderId: String
    let blockTransactionId: String?
    let amount: Double
    let actualAmount: Double
    let token: String
    let chain: String?
    let status: Int
    let notifyUrl: String?
    let redirectUrl: String?
    let callbackNum: Int?
    let callbackConfirm: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tradeId = "trade_id"
        case orderId = "order_id"
        case blockTransactionId = "block_transaction_id"
        case amount
        case actualAmount = "actual_amount"
        case token
        case chain
        case status
        case notifyUrl = "notify_url"
        case redirectUrl = "redirect_url"
        case callbackNum = "callback_num"
        case callbackConfirm = "callback_confirm"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusText: String {
        switch status {
        case 1: return "待支付"
        case 2: return "已支付"
        case 3: return "已过期"
        default: return "未知"
        }
    }
}

// MARK: - Wallet Address
struct WalletAddress: Codable, Identifiable {
    let id: UInt64
    let token: String
    let chain: String?
    let status: Int64
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, token, chain, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isEnabled: Bool { status == 1 }

    var truncatedAddress: String {
        guard token.count > 12 else { return token }
        return "\(token.prefix(6))...\(token.suffix(6))"
    }
}

// MARK: - Authorization Create Response
struct AuthorizationCreateResponse: Codable {
    let authNo: String
    let password: String
    let amountUsdt: Double?
    let merchantWallet: String?
    let expireTime: Int64?
    let authUrl: String?
    let chain: String?

    enum CodingKeys: String, CodingKey {
        case authNo = "auth_no"
        case password
        case amountUsdt = "amount_usdt"
        case merchantWallet = "merchant_wallet"
        case expireTime = "expire_time"
        case authUrl = "auth_url"
        case chain
    }
}

// MARK: - Deduction Create Response
struct DeductionCreateResponse: Codable {
    let deductNo: String
    let password: String?
    let amountCny: Double
    let amountUsdt: Double
    let remainingUsdt: Double
    let status: String?
    let customerWallet: String?

    enum CodingKeys: String, CodingKey {
        case deductNo = "deduct_no"
        case password
        case amountCny = "amount_cny"
        case amountUsdt = "amount_usdt"
        case remainingUsdt = "remaining_usdt"
        case status
        case customerWallet = "customer_wallet"
    }
}

// MARK: - Authorization Info Response
struct AuthorizationInfoResponse: Codable {
    let id: UInt64?
    let authNo: String
    let password: String?
    let customerWallet: String?
    let merchantWallet: String?
    let authorizedUsdt: Double
    let usedUsdt: Double
    let remainingUsdt: Double
    let status: Int
    let tableNo: String?
    let customerName: String?
    let chain: String?

    enum CodingKeys: String, CodingKey {
        case id
        case authNo = "auth_no"
        case password
        case customerWallet = "customer_wallet"
        case merchantWallet = "merchant_wallet"
        case authorizedUsdt = "authorized_usdt"
        case usedUsdt = "used_usdt"
        case remainingUsdt = "remaining_usdt"
        case status
        case tableNo = "table_no"
        case customerName = "customer_name"
        case chain
    }

    var statusText: String {
        switch status {
        case 1: return "待授权"
        case 2: return "有效"
        case 3: return "已撤销"
        case 4: return "已用尽"
        default: return "未知"
        }
    }
}

// MARK: - Wallet Add Response
struct WalletAddResponse: Codable {
    let wallet: WalletAddress
    let qrcodeContent: String?
    let qrcodeStreamUrl: String?

    enum CodingKeys: String, CodingKey {
        case wallet
        case qrcodeContent = "qrcode_content"
        case qrcodeStreamUrl = "qrcode_stream_url"
    }
}
