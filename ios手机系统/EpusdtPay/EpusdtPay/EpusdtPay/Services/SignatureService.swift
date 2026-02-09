//
//  SignatureService.swift
//  EpusdtPay
//
//  MD5 signature generation for /api/v1/wallet/* endpoints
//

import Foundation
import CryptoKit

struct SignatureService {
    static var shared = SignatureService()

    private var apiAuthToken: String = ""

    mutating func setApiAuthToken(_ token: String) {
        self.apiAuthToken = token
    }

    func generateSignature(params: [String: Any]) -> String {
        var pairs: [String] = []
        for (key, value) in params {
            if key == "signature" { continue }
            let strValue = toStringValue(value)
            if strValue.isEmpty { continue }
            pairs.append("\(key)=\(strValue)")
        }
        pairs.sort()
        let joined = pairs.joined(separator: "&")
        let signString = joined + apiAuthToken
        return md5Hash(signString)
    }

    private func toStringValue(_ value: Any) -> String {
        switch value {
        case let v as Double:
            if v == v.rounded(.towardZero) && v >= 0 && v < Double(Int64.max) {
                return String(Int64(v))
            }
            return String(v)
        case let v as Int:
            return String(v)
        case let v as Int64:
            return String(v)
        case let v as UInt64:
            return String(v)
        case let v as String:
            return v
        default:
            return ""
        }
    }

    private func md5Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
