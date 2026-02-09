//
//  EpusdtPayApp.swift
//  EpusdtPay
//
//  Entry point of the Epusdt iOS application
//  Supports: iOS 14+, iPad compatible, Multi-chain support
//

import SwiftUI

@main
struct EpusdtPayApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var walletViewModel = WalletViewModel()
    @StateObject var paymentViewModel = PaymentViewModel()

    init() {
        // Check authentication state on app launch
        authViewModel.checkAuthState()
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                TabBarView()
                    .environmentObject(authViewModel)
                    .environmentObject(walletViewModel)
                    .environmentObject(paymentViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
