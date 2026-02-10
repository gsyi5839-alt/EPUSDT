//
//  WalletViewModel.swift
//  EpusdtPay
//
//  Wallet address management
//

import Foundation
import Combine

class WalletViewModel: ObservableObject {
    @Published var wallets: [WalletAddress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Add wallet form
    @Published var newWalletToken: String = ""
    @Published var newWalletChain: String = "tron"

    private let apiService = APIService.shared

    func loadWallets() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await apiService.fetchWalletList()
                await MainActor.run {
                    self.wallets = result
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

    func addWallet() {
        guard !newWalletToken.isEmpty else {
            errorMessage = "请输入钱包地址"
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await apiService.addWallet(token: newWalletToken, chain: newWalletChain)
                await MainActor.run {
                    self.newWalletToken = ""
                    self.successMessage = "钱包添加成功"
                    self.isLoading = false
                }
                // Reload list
                let result = try await apiService.fetchWalletList()
                await MainActor.run {
                    self.wallets = result
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleWalletStatus(_ wallet: WalletAddress) {
        let newStatus = wallet.isEnabled ? 2 : 1
        Task {
            do {
                try await apiService.updateWalletStatus(id: wallet.id, status: newStatus)
                let result = try await apiService.fetchWalletList()
                await MainActor.run {
                    self.wallets = result
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteWallet(_ wallet: WalletAddress) {
        Task {
            do {
                try await apiService.deleteWallet(id: wallet.id)
                let result = try await apiService.fetchWalletList()
                await MainActor.run {
                    self.wallets = result
                    self.successMessage = "钱包已删除"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
