//
//  APIService.swift
//  EpusdtPay
//
//  Network API service for backend communication
//

import Foundation
import Combine

class APIService {
    static let shared = APIService()

    private let baseURL = "http://localhost:8000"
    private var authToken: String?

    private init() {}

    // MARK: - Token Management
    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func clearAuthToken() {
        self.authToken = nil
    }

    // MARK: - Authentication
    func login(username: String, password: String) async throws -> LoginResponse {
        let endpoint = "\(baseURL)/admin/api/login"
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func fetchCurrentUser() async throws -> User {
        let endpoint = "\(baseURL)/admin/api/me"
        let response: APIResponse<User> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    // MARK: - Merchant Authentication
    func merchantRegister(username: String, password: String, email: String, merchantName: String, walletToken: String) async throws -> MerchantLoginResponse {
        let endpoint = "\(baseURL)/api/v1/merchant/register"
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "email": email,
            "merchant_name": merchantName,
            "wallet_token": walletToken
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func merchantLogin(username: String, password: String) async throws -> MerchantLoginResponse {
        let endpoint = "\(baseURL)/api/v1/merchant/login"
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func fetchMerchantProfile() async throws -> MerchantProfile {
        let endpoint = "\(baseURL)/api/v1/merchant/profile"
        let response: APIResponse<MerchantProfile> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    // MARK: - Admin Dashboard APIs (JWT auth)
    func fetchOrders() async throws -> [Order] {
        let endpoint = "\(baseURL)/admin/api/orders"
        let response: APIResponse<[Order]> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    func fetchAuthorizations() async throws -> [KtvAuthorization] {
        let endpoint = "\(baseURL)/admin/api/authorizations"
        let response: APIResponse<[KtvAuthorization]> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    func fetchDeductions() async throws -> [KtvDeduction] {
        let endpoint = "\(baseURL)/admin/api/deductions"
        let response: APIResponse<[KtvDeduction]> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    // MARK: - Authorization Payment APIs (public, no signature needed)
    func createAuthorization(amountUsdt: Double, tableNo: String, customerName: String, remark: String, chain: String) async throws -> AuthorizationCreateResponse {
        let endpoint = "\(baseURL)/api/v1/auth/create"
        let body: [String: Any] = [
            "amount_usdt": amountUsdt,
            "table_no": tableNo,
            "customer_name": customerName,
            "remark": remark,
            "chain": chain
        ]
        let response: APIResponse<AuthorizationCreateResponse> = try await request(endpoint: endpoint, method: .post, body: body)
        return response.data
    }

    func deductFromAuthorization(password: String, amountCny: Double, productInfo: String, operatorId: String) async throws -> DeductionCreateResponse {
        let endpoint = "\(baseURL)/api/v1/auth/deduct"
        let body: [String: Any] = [
            "password": password,
            "amount_cny": amountCny,
            "product_info": productInfo,
            "operator_id": operatorId
        ]
        let response: APIResponse<DeductionCreateResponse> = try await request(endpoint: endpoint, method: .post, body: body)
        return response.data
    }

    func getAuthorizationInfo(password: String) async throws -> AuthorizationInfoResponse {
        let endpoint = "\(baseURL)/api/v1/auth/info/\(password)"
        let response: APIResponse<AuthorizationInfoResponse> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    func getDeductionHistory(password: String) async throws -> [KtvDeduction] {
        let endpoint = "\(baseURL)/api/v1/auth/history/\(password)"
        let response: APIResponse<[KtvDeduction]> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    // MARK: - Merchant Dashboard APIs (merchant JWT auth)
    func fetchMerchantAuthorizations(page: Int = 1, pageSize: Int = 100) async throws -> [KtvAuthorization] {
        let endpoint = "\(baseURL)/api/v1/merchant/authorizations?page=\(page)&page_size=\(pageSize)"
        let response: APIResponse<PaginatedList<KtvAuthorization>> = try await request(endpoint: endpoint, method: .get)
        return response.data.list
    }

    func fetchMerchantDeductions(page: Int = 1, pageSize: Int = 100) async throws -> [KtvDeduction] {
        let endpoint = "\(baseURL)/api/v1/merchant/deductions?page=\(page)&page_size=\(pageSize)"
        let response: APIResponse<PaginatedList<KtvDeduction>> = try await request(endpoint: endpoint, method: .get)
        return response.data.list
    }

    func confirmAuthorization(password: String, customerWallet: String) async throws {
        let endpoint = "\(baseURL)/api/v1/auth/confirm"
        let body: [String: Any] = [
            "password": password,
            "customer_wallet": customerWallet
        ]
        let _: APIResponse<String> = try await request(endpoint: endpoint, method: .post, body: body)
    }

    // MARK: - Merchant Wallet APIs (JWT auth)
    func fetchWalletList() async throws -> [WalletAddress] {
        let endpoint = "\(baseURL)/api/v1/merchant/wallets"
        let response: APIResponse<[WalletAddress]> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    func addWallet(token: String, chain: String) async throws -> WalletAddress {
        let endpoint = "\(baseURL)/api/v1/merchant/wallets"
        let body: [String: Any] = [
            "token": token,
            "chain": chain
        ]
        let response: APIResponse<WalletAddress> = try await request(endpoint: endpoint, method: .post, body: body)
        return response.data
    }

    func updateWalletStatus(id: UInt64, status: Int) async throws {
        let endpoint = "\(baseURL)/api/v1/merchant/wallets/status"
        let body: [String: Any] = [
            "id": id,
            "status": status
        ]
        let _: APIResponse<String> = try await request(endpoint: endpoint, method: .put, body: body)
    }

    func deleteWallet(id: UInt64) async throws {
        let endpoint = "\(baseURL)/api/v1/merchant/wallets/\(id)"
        let _: APIResponse<String> = try await request(endpoint: endpoint, method: .delete)
    }

    // MARK: - Signed Request Helper (for wallet APIs)
    private func signedRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        body: [String: Any]
    ) async throws -> T {
        var signedBody = body
        let signature = SignatureService.shared.generateSignature(params: body)
        signedBody["signature"] = signature
        return try await request(endpoint: endpoint, method: method, body: signedBody)
    }

    // MARK: - Generic Request Helper
    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        // 先检查后端业务状态码（后端错误时 HTTP 返回 200 但 status_code != 200）
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let statusCode = json["status_code"] as? Int,
           statusCode != 200 {
            let message = json["message"] as? String ?? "请求失败"
            throw APIError.serverError(message)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Response Models
struct LoginResponse: Codable {
    let statusCode: Int
    let message: String
    let data: TokenData
    let requestId: String?

    struct TokenData: Codable {
        let token: String
    }

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message
        case data
        case requestId = "request_id"
    }
}

// MARK: - Generic API Response Wrapper
struct APIResponse<T: Decodable>: Decodable {
    let statusCode: Int
    let message: String
    let data: T
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message
        case data
        case requestId = "request_id"
    }
}

// MARK: - Paginated List Response
struct PaginatedList<T: Decodable>: Decodable {
    let list: [T]
    let total: Int64
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case list
        case total
        case page
        case pageSize = "page_size"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([T].self, forKey: .list) ?? []
        self.total = try container.decodeIfPresent(Int64.self, forKey: .total) ?? 0
        self.page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        self.pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? 20
    }
}

// MARK: - Merchant Response Models
struct MerchantLoginResponse: Codable {
    let statusCode: Int
    let message: String
    let data: MerchantLoginData
    let requestId: String?

    struct MerchantLoginData: Codable {
        let merchant: MerchantProfile
        let token: String
    }

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message
        case data
        case requestId = "request_id"
    }
}

struct MerchantProfile: Codable {
    let id: UInt64
    let username: String
    let email: String
    let merchantName: String
    let walletToken: String
    let status: Int
    let balance: Double
    let usdtRate: Double
    let apiToken: String?
    let lastLoginAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case merchantName = "merchant_name"
        case walletToken = "wallet_token"
        case status
        case balance
        case usdtRate = "usdt_rate"
        case apiToken = "api_token"
        case lastLoginAt = "last_login_at"
    }
}
