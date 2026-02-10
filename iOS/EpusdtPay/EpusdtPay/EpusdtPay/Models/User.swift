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

    var roleText: String {
        switch roleId {
        case 1: return "管理员"
        case 2: return "操作员"
        default: return "用户"
        }
    }
}
