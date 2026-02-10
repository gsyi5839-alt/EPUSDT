//
//  PaymentViewModel.swift
//  EpusdtPay
//
//  Authorization and deduction management
//

import Foundation
import Combine

class PaymentViewModel: ObservableObject {
    // MARK: - Create Authorization Form
    @Published var authAmount: String = ""
    @Published var authTableNo: String = ""
    @Published var authCustomerName: String = ""
    @Published var authRemark: String = ""
    @Published var authChain: String = "tron"
    @Published var createResult: AuthorizationCreateResponse?

    // MARK: - Deduct Form
    @Published var deductPassword: String = ""
    @Published var deductAmountCny: String = ""
    @Published var deductProductInfo: String = ""
    @Published var deductOperatorId: String = ""
    @Published var deductResult: DeductionCreateResponse?

    // MARK: - Query
    @Published var queryPassword: String = ""
    @Published var authInfo: AuthorizationInfoResponse?
    @Published var deductionHistory: [KtvDeduction] = []

    // MARK: - State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let apiService = APIService.shared

    // MARK: - Create Authorization
    func createAuthorization() {
        guard let amount = Double(authAmount), amount > 0 else {
            errorMessage = "请输入有效的授权金额"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        createResult = nil

        Task {
            do {
                let result = try await apiService.createAuthorization(
                    amountUsdt: amount,
                    tableNo: authTableNo,
                    customerName: authCustomerName,
                    remark: authRemark,
                    chain: authChain
                )
                await MainActor.run {
                    self.createResult = result
                    self.successMessage = "授权创建成功"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Deduct
    func deductFromAuthorization() {
        guard !deductPassword.isEmpty else {
            errorMessage = "请输入密码凭证"
            return
        }
        guard let amount = Double(deductAmountCny), amount > 0 else {
            errorMessage = "请输入有效的扣款金额"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        deductResult = nil

        Task {
            do {
                let result = try await apiService.deductFromAuthorization(
                    password: deductPassword,
                    amountCny: amount,
                    productInfo: deductProductInfo,
                    operatorId: deductOperatorId
                )
                await MainActor.run {
                    self.deductResult = result
                    self.successMessage = "扣款成功"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Query Authorization Info
    func queryAuthInfo() {
        guard !queryPassword.isEmpty else {
            errorMessage = "请输入密码凭证"
            return
        }

        isLoading = true
        errorMessage = nil
        authInfo = nil
        deductionHistory = []

        Task {
            do {
                let info = try await apiService.getAuthorizationInfo(password: queryPassword)
                await MainActor.run {
                    self.authInfo = info
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Query Deduction History
    func queryDeductionHistory() {
        guard !queryPassword.isEmpty else { return }

        Task {
            do {
                let history = try await apiService.getDeductionHistory(password: queryPassword)
                await MainActor.run {
                    self.deductionHistory = history
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Reset Forms
    func resetCreateForm() {
        authAmount = ""
        authTableNo = ""
        authCustomerName = ""
        authRemark = ""
        authChain = "tron"
        createResult = nil
        errorMessage = nil
        successMessage = nil
    }

    func resetDeductForm() {
        deductPassword = ""
        deductAmountCny = ""
        deductProductInfo = ""
        deductOperatorId = ""
        deductResult = nil
        errorMessage = nil
        successMessage = nil
    }
}
