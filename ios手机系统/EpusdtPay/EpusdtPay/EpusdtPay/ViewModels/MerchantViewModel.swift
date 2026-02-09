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
    @Published var isLoading = false
    @Published var errorMessage: String?

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

                let (fetchedAuths, fetchedDeducts) = try await (authsResult, deductsResult)

                await MainActor.run {
                    self.orders = []
                    self.authorizations = fetchedAuths
                    self.deductions = fetchedDeducts
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
}
