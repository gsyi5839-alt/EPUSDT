//
//  TabBarView.swift
//  EpusdtPay
//
//  Main tab bar navigation
//

import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var merchantViewModel: MerchantViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Customer Tab - Scan QR Code
            CustomerHomeView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("扫码")
                }
                .tag(0)

            // Merchant Dashboard
            MerchantHomeView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("仪表盘")
                }
                .tag(1)

            // Payment/Deduction
            PayView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("收款")
                }
                .tag(2)

            // Wallet Management
            WalletManageView()
                .tabItem {
                    Image(systemName: "wallet.pass.fill")
                    Text("钱包")
                }
                .tag(3)

            // Profile
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("我的")
                }
                .tag(4)
        }
        .accentColor(Color.gold)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
