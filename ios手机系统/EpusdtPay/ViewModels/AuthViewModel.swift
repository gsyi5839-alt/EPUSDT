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
    @Published var authToken: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared

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
                    self.errorMessage = nil
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

    func register(phone: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "Registration is currently disabled. Please contact administrator.")
    }

    func checkAuthState() {
        guard let token = keychainService.getToken() else {
            isLoggedIn = false
            return
        }

        Task {
            do {
                // Verify token is still valid
                apiService.setAuthToken(token)
                let user = try await apiService.fetchCurrentUser()

                await MainActor.run {
                    self.currentUser = user
                    self.authToken = token
                    self.isLoggedIn = true
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
        authToken = nil
        errorMessage = nil
    }
}
