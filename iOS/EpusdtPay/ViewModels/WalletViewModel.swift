//
//  WalletViewModel.swift
//  EpusdtPay
//
//  Wallet management and blockchain interaction
//

import Foundation
import Combine

class WalletViewModel: ObservableObject {
    @Published var connectedWallets: [Wallet] = []
    @Published var selectedWallet: Wallet?
    @Published var usdtBalance: Double = 0.0
    @Published var isLoading = false

    private let apiService = APIService.shared

    func connectWallet(address: String, chain: String) {
        let wallet = Wallet(
            id: UUID().uuidString,
            address: address,
            chain: chain,
            connectedDate: Date()
        )
        connectedWallets.append(wallet)
        selectedWallet = wallet
    }

    func disconnectWallet(id: String) {
        connectedWallets.removeAll { $0.id == id }
        if selectedWallet?.id == id {
            selectedWallet = connectedWallets.first
        }
    }

    func fetchBalance(wallet: Wallet) {
        isLoading = true
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.usdtBalance = 1000.0 // Demo balance
            self.isLoading = false
        }
    }
}
