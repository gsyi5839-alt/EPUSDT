//
//  AuthViewModel.swift
//  EpusdtPay
//
//  Authentication business logic
//

import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var merchantProfile: MerchantProfile?
    @Published var authToken: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isMerchantUser = false // 标识当前是商家登录还是管理员登录

    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared

    // MARK: - 管理员登录
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Task {
            do {
                // Call real API
                let response = try await apiService.login(username: username, password: password)
                let token = response.data.token

                // Store token in Keychain
                try keychainService.saveToken(token)
                apiService.setAuthToken(token)

                // Fetch user information
                let user = try await apiService.fetchCurrentUser()

                // Update UI on main thread
                await MainActor.run {
                    self.currentUser = user
                    self.authToken = token
                    self.isLoggedIn = true
                    self.isLoading = false
                    self.isMerchantUser = false
                    self.errorMessage = nil
                    UserDefaults.standard.set("admin", forKey: "epusdt_login_type")
                    completion(true, nil)
                }
            } catch {
                let errorMsg = error.localizedDescription
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }

    // MARK: - 商家登录
    func merchantLogin(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Task {
            do {
                let response = try await apiService.merchantLogin(username: username, password: password)
                let token = response.data.token

                // Store token in Keychain
                try keychainService.saveToken(token)
                apiService.setAuthToken(token)

                // Update UI on main thread
                await MainActor.run {
                    self.merchantProfile = response.data.merchant
                    self.authToken = token
                    self.isLoggedIn = true
                    self.isLoading = false
                    self.isMerchantUser = true
                    self.errorMessage = nil
                    UserDefaults.standard.set("merchant", forKey: "epusdt_login_type")
                    completion(true, nil)
                }
            } catch {
                let errorMsg = error.localizedDescription
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }

    // MARK: - 商家注册
    func register(username: String, password: String, email: String, merchantName: String, walletToken: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Task {
            do {
                let response = try await apiService.merchantRegister(
                    username: username,
                    password: password,
                    email: email,
                    merchantName: merchantName,
                    walletToken: walletToken
                )
                let token = response.data.token

                // Store token in Keychain
                try keychainService.saveToken(token)
                apiService.setAuthToken(token)

                await MainActor.run {
                    self.merchantProfile = response.data.merchant
                    self.authToken = token
                    self.isLoggedIn = true
                    self.isLoading = false
                    self.isMerchantUser = true
                    self.errorMessage = nil
                    UserDefaults.standard.set("merchant", forKey: "epusdt_login_type")
                    completion(true, nil)
                }
            } catch {
                let errorMsg = error.localizedDescription
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }

    func checkAuthState() {
        guard let token = keychainService.getToken() else {
            isLoggedIn = false
            return
        }

        let loginType = UserDefaults.standard.string(forKey: "epusdt_login_type") ?? "admin"
        apiService.setAuthToken(token)

        Task {
            do {
                if loginType == "merchant" {
                    let profile = try await apiService.fetchMerchantProfile()
                    await MainActor.run {
                        self.merchantProfile = profile
                        self.authToken = token
                        self.isLoggedIn = true
                        self.isMerchantUser = true
                    }
                } else {
                    let user = try await apiService.fetchCurrentUser()
                    await MainActor.run {
                        self.currentUser = user
                        self.authToken = token
                        self.isLoggedIn = true
                        self.isMerchantUser = false
                    }
                }
            } catch {
                // Token expired or invalid, clear it
                await MainActor.run {
                    logout()
                }
            }
        }
    }

    func logout() {
        keychainService.clearAll()
        apiService.clearAuthToken()
        isLoggedIn = false
        currentUser = nil
        merchantProfile = nil
        authToken = nil
        errorMessage = nil
        isMerchantUser = false
        UserDefaults.standard.removeObject(forKey: "epusdt_login_type")
    }
}
