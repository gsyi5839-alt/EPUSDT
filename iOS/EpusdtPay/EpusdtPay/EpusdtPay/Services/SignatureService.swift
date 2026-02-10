//
//  SignatureService.swift
//  EpusdtPay
//
//  Signature generation for API endpoints (MD5 v1 & HMAC-SHA256 v2)
//

import Foundation
import CryptoKit

struct SignatureService {
    static var shared = SignatureService()

    private var apiAuthToken: String = ""

    mutating func setApiAuthToken(_ token: String) {
        self.apiAuthToken = token
    }

    /// Generate signature with auto-injected timestamp, nonce, sign_version
    func generateSignedParams(params: [String: Any], useV2: Bool = true) -> [String: Any] {
        var signedParams = params
        signedParams["timestamp"] = Int64(Date().timeIntervalSince1970)
        signedParams["nonce"] = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        if useV2 {
            signedParams["sign_version"] = "v2"
        }
        let signature = useV2 ? generateHmacSha256Signature(params: signedParams) : generateMd5Signature(params: signedParams)
        signedParams["signature"] = signature
        return signedParams
    }

    /// Legacy MD5 signature (v1)
    func generateSignature(params: [String: Any]) -> String {
        return generateMd5Signature(params: params)
    }

    // MARK: - HMAC-SHA256 (v2, recommended)
    private func generateHmacSha256Signature(params: [String: Any]) -> String {
        let sortedPairs = buildSortedPairs(params: params)
        let signString = sortedPairs.joined(separator: "&")
        let key = SymmetricKey(data: Data(apiAuthToken.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signString.utf8), using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - MD5 (v1, legacy)
    private func generateMd5Signature(params: [String: Any]) -> String {
        let sortedPairs = buildSortedPairs(params: params)
        let joined = sortedPairs.joined(separator: "&")
        let signString = joined + apiAuthToken
        return md5Hash(signString)
    }

    // MARK: - Helpers
    private func buildSortedPairs(params: [String: Any]) -> [String] {
        var pairs: [String] = []
        for (key, value) in params {
            if key == "signature" { continue }
            let strValue = toStringValue(value)
            if strValue.isEmpty { continue }
            pairs.append("\(key)=\(strValue)")
        }
        pairs.sort()
        return pairs
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
