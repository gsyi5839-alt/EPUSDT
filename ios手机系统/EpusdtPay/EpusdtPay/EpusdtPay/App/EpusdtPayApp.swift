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
    @StateObject var merchantViewModel = MerchantViewModel()
    @StateObject var walletViewModel = WalletViewModel()
    @StateObject var paymentViewModel = PaymentViewModel()
    @StateObject var themeManager = ThemeManager.shared
    @State private var themeRefreshID = UUID()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    TabBarView()
                        .environmentObject(authViewModel)
                        .environmentObject(merchantViewModel)
                        .environmentObject(walletViewModel)
                        .environmentObject(paymentViewModel)
                        .environmentObject(themeManager)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                        .environmentObject(themeManager)
                }
            }
            .id(themeRefreshID)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .onChange(of: themeManager.currentTheme) {
                themeRefreshID = UUID()
            }
            .onAppear {
                // Check authentication state on app launch
                authViewModel.checkAuthState()
            }
        }
    }
}
