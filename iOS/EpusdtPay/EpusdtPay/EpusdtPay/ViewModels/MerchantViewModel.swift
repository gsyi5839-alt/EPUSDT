//
//  MerchantViewModel.swift
//  EpusdtPay
//
//  Dashboard data management
//

import Foundation
import Combine

class MerchantViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var authorizations: [KtvAuthorization] = []
    @Published var deductions: [KtvDeduction] = []
    @Published var balance: Double = 0
    @Published var withdrawals: [MerchantWithdrawal] = []
    @Published var isLoading = false
    @Published var isWithdrawing = false
    @Published var errorMessage: String?
    @Published var withdrawalSuccess = false

    private let apiService = APIService.shared

    // MARK: - Computed Stats
    var activeAuthCount: Int {
        authorizations.filter { $0.status == 2 }.count
    }

    var todayDeductionCount: Int {
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return deductions.filter { Double($0.deductTime ?? 0) >= todayStart }.count
    }

    var totalRevenueUsdt: Double {
        deductions.filter { $0.status == 2 }.reduce(0) { $0 + $1.amountUsdt }
    }

    var todayRevenueCny: Double {
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return deductions
            .filter { $0.status == 2 && Double($0.deductTime ?? 0) >= todayStart }
            .reduce(0) { $0 + $1.amountCny }
    }

    // MARK: - Data Loading
    func loadDashboard() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let authsResult = apiService.fetchMerchantAuthorizations()
                async let deductsResult = apiService.fetchMerchantDeductions()
                async let balanceResult = apiService.fetchMerchantBalance()

                let (fetchedAuths, fetchedDeducts, fetchedBalance) = try await (authsResult, deductsResult, balanceResult)

                await MainActor.run {
                    self.orders = []
                    self.authorizations = fetchedAuths
                    self.deductions = fetchedDeducts
                    self.balance = fetchedBalance.balance
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Balance
    func loadBalance() {
        Task {
            do {
                let result = try await apiService.fetchMerchantBalance()
                await MainActor.run {
                    self.balance = result.balance
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Withdrawals
    func loadWithdrawals() {
        Task {
            do {
                let result = try await apiService.fetchWithdrawals()
                await MainActor.run {
                    self.withdrawals = result
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func createWithdrawal(amount: Double, toWallet: String, chain: String = "BSC") {
        isWithdrawing = true
        withdrawalSuccess = false
        errorMessage = nil
        Task {
            do {
                let _ = try await apiService.createWithdrawal(amount: amount, toWallet: toWallet, chain: chain)
                await MainActor.run {
                    self.isWithdrawing = false
                    self.withdrawalSuccess = true
                    self.loadBalance()
                    self.loadWithdrawals()
                }
            } catch {
                await MainActor.run {
                    self.isWithdrawing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
