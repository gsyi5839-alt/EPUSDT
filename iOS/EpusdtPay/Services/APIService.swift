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

    // MARK: - Authentication
    func login(username: String, password: String) async throws -> LoginResponse {
        let endpoint = "\(baseURL)/admin/api/login"
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func register(phone: String, password: String) async throws -> RegisterResponse {
        let endpoint = "\(baseURL)/api/v1/auth/register"
        let body: [String: Any] = [
            "phone": phone,
            "password": password
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func fetchCurrentUser() async throws -> User {
        let endpoint = "\(baseURL)/admin/api/me"
        let response: APIResponse<User> = try await request(endpoint: endpoint, method: .get)
        return response.data
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func clearAuthToken() {
        self.authToken = nil
    }

    // MARK: - Wallet
    func getWalletList() async throws -> [Wallet] {
        let endpoint = "\(baseURL)/wallet/list"
        return try await request(endpoint: endpoint, method: .get)
    }

    func addWallet(address: String, chain: String) async throws -> Wallet {
        let endpoint = "\(baseURL)/wallet/add"
        let body: [String: Any] = [
            "address": address,
            "chain": chain
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    // MARK: - Payment
    func createOrder(merchantWallet: String, amount: Double, chain: String) async throws -> Payment {
        let endpoint = "\(baseURL)/order/create-transaction"
        let body: [String: Any] = [
            "merchant_wallet": merchantWallet,
            "amount_usd": amount,
            "chain": chain
        ]
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func authorizePayment(orderId: String, customerWallet: String, amount: Double) async throws {
        let endpoint = "\(baseURL)/auth/create"
        let body: [String: Any] = [
            "order_id": orderId,
            "customer_wallet": customerWallet,
            "authorized_amount": amount
        ]
        let _: LoginResponse = try await request(endpoint: endpoint, method: .post, body: body)
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
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

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
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

struct RegisterResponse: Codable {
    let success: Bool
    let message: String
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
