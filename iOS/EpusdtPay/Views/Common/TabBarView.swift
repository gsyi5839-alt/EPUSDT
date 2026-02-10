//
//  TabBarView.swift
//  EpusdtPay
//
//  Main tab bar view for navigation
//

import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0f1218),
                    Color(hex: 0x171c25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // Merchant Tab
                MerchantHomeView()
                    .tabItem {
                        Image(systemName: "rectangle.grid.2x2")
                        Text("Merchant")
                    }
                    .tag(0)

                // Payment Tab
                ScanQRView()
                    .tabItem {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Pay")
                    }
                    .tag(1)

                // Wallet Tab
                WalletView()
                    .tabItem {
                        Image(systemName: "wallet.pass")
                        Text("Wallet")
                    }
                    .tag(2)

                // Profile Tab
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Profile")
                    }
                    .tag(3)
            }
            .accentColor(Color(hex: 0xd4af37))
        }
    }
}

// MARK: - Merchant Home View
struct MerchantHomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Merchant Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: 0xe6e6e6))
                Spacer()
            }
            .padding(20)
            .navigationTitle("Epusdt Pay")
        }
    }
}

// MARK: - Scan QR View
struct ScanQRView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Scan Merchant QR Code")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: 0xe6e6e6))
                Spacer()

                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: 0xd4af37).opacity(0.5))

                Text("Tap to scan QR code")
                    .foregroundColor(Color(hex: 0x999999))

                Spacer()
            }
            .padding(20)
            .navigationTitle("Payment")
        }
    }
}

// MARK: - Wallet View
struct WalletView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Connected Wallets")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: 0xe6e6e6))
                Spacer()

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USDT Balance")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x999999))
                            Text("$0.00")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: 0xd4af37))
                        }
                        Spacer()
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: 0xd4af37))
                    }
                    .padding(16)
                    .background(Color(hex: 0x171c25))
                    .cornerRadius(12)
                }
                .padding(20)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Wallet")
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: 0xd4af37))

                    Text("User Account")
                        .font(.headline)
                        .foregroundColor(Color(hex: 0xe6e6e6))
                }
                .padding(20)

                // Menu Items
                VStack(spacing: 12) {
                    ProfileMenuItem(icon: "lock", title: "Change Password")
                    ProfileMenuItem(icon: "faceid", title: "Biometric Settings")
                    ProfileMenuItem(icon: "gear", title: "Settings")
                    ProfileMenuItem(icon: "questionmark.circle", title: "Help & Support")
                }
                .padding(20)

                Spacer()

                // Logout Button
                Button(action: authViewModel.logout) {
                    Text("Logout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(hex: 0xe74c3c).opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(20)
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Profile Menu Item
struct ProfileMenuItem: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: 0xd4af37))
                .frame(width: 32)

            Text(title)
                .foregroundColor(Color(hex: 0xe6e6e6))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: 0x999999))
        }
        .padding(12)
        .background(Color(hex: 0x171c25))
        .cornerRadius(8)
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
        .environmentObject(WalletViewModel())
        .environmentObject(PaymentViewModel())
}
